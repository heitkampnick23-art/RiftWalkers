// RiftWalkers API — Cloudflare Worker + D1
// Full game backend: auth, player data, creatures, leaderboards, game state.

const RATE_LIMIT_WINDOW = 60_000;
const rateLimits = new Map();

// Convert snake_case keys to camelCase (handles iOS encoder)
function toCamel(obj) {
  if (Array.isArray(obj)) return obj.map(toCamel);
  if (obj !== null && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [
        k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()),
        toCamel(v)
      ])
    );
  }
  return obj;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Health check
    if (path === '/health') {
      return json({ status: 'ok', service: 'riftwalkers-api', version: '2.0' });
    }

    // Rate limiting
    const deviceId = request.headers.get('X-Device-ID') || request.headers.get('CF-Connecting-IP') || 'unknown';
    const maxPerMinute = parseInt(env.RATE_LIMIT_PER_MINUTE) || 30;
    if (isRateLimited(deviceId, maxPerMinute)) {
      return jsonErr('Rate limited. Try again shortly.', 429);
    }

    try {
      // ─── AI Proxies ───
      if (path === '/v1/images/generations' && method === 'POST') {
        return await proxyToOpenAI(request, env, 'https://api.openai.com/v1/images/generations');
      }
      if (path === '/v1/chat/completions' && method === 'POST') {
        return await proxyToOpenAI(request, env, 'https://api.openai.com/v1/chat/completions');
      }
      // ElevenLabs TTS
      if (path === '/v1/voice/tts' && method === 'POST') {
        return await elevenLabsTTS(request, env);
      }
      // AI Companion conversational endpoint
      if (path === '/v1/companion/chat' && method === 'POST') {
        return await companionChat(request, env);
      }

      // ─── Auth ───
      if (path === '/v1/auth/register' && method === 'POST') return await authRegister(request, env);
      if (path === '/v1/auth/login' && method === 'POST') return await authLogin(request, env);
      if (path === '/v1/auth/refresh' && method === 'POST') return await authRefresh(request, env);

      // ─── Protected routes (require auth) ───
      const player = await authenticate(request, env);
      if (!player) return jsonErr('Unauthorized', 401);

      // Player
      if (path === '/v1/player/profile' && method === 'GET') return await getProfile(player, env);
      if (path === '/v1/player/profile' && method === 'PUT') return await updateProfile(request, player, env);
      if (path === '/v1/player/location' && method === 'POST') return await updateLocation(request, player, env);

      // Creatures
      if (path === '/v1/creatures' && method === 'GET') return await getCreatures(player, env);
      if (path === '/v1/creatures' && method === 'POST') return await addCreature(request, player, env);
      if (path === '/v1/creatures/evolve' && method === 'POST') return await evolveCreature(request, player, env);
      if (path.startsWith('/v1/creatures/') && method === 'DELETE') {
        const id = path.split('/').pop();
        return await releaseCreature(id, player, env);
      }

      // Inventory
      if (path === '/v1/inventory' && method === 'GET') return await getInventory(player, env);
      if (path === '/v1/inventory' && method === 'POST') return await addInventoryItem(request, player, env);

      // Leaderboard
      if (path.startsWith('/v1/leaderboard/') && method === 'GET') {
        const type = path.split('/').pop().split('?')[0];
        const page = parseInt(url.searchParams.get('page') || '0');
        return await getLeaderboard(type, page, env);
      }

      // Game state (full save/load)
      if (path === '/v1/gamestate' && method === 'GET') return await loadGameState(player, env);
      if (path === '/v1/gamestate' && method === 'POST') return await saveGameState(request, player, env);

      // Quests
      if (path === '/v1/quests/daily' && method === 'GET') return await getDailyQuests(player, env);

      // Essences
      if (path === '/v1/essences' && method === 'GET') return await getEssences(player, env);

      return jsonErr('Not found', 404);
    } catch (err) {
      console.error('API Error:', err);
      return jsonErr(`Server error: ${err.message}`, 500);
    }
  },
};

// ═══════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════

async function authRegister(request, env) {
  const raw = await request.json();
  const deviceId = raw.deviceId || raw.device_id;
  const displayName = raw.displayName || raw.display_name;
  const appleUserId = raw.appleUserId || raw.apple_user_id;
  if (!deviceId) return jsonErr('deviceId required', 400);

  // Check if device already registered
  const existing = await env.DB.prepare('SELECT id FROM players WHERE device_id = ?').bind(deviceId).first();
  if (existing) return jsonErr('Device already registered. Use /auth/login.', 409);

  const playerId = crypto.randomUUID();
  const name = displayName || 'New Walker';

  await env.DB.prepare(`
    INSERT INTO players (id, device_id, apple_user_id, display_name)
    VALUES (?, ?, ?, ?)
  `).bind(playerId, deviceId, appleUserId || null, name).run();

  // Initialize essences for all mythologies
  const mythologies = ['Norse', 'Greek', 'Egyptian', 'Japanese', 'Celtic', 'Hindu', 'Aztec', 'Slavic', 'Chinese', 'African'];
  for (const myth of mythologies) {
    await env.DB.prepare('INSERT INTO essences (player_id, mythology, amount) VALUES (?, ?, 0)')
      .bind(playerId, myth).run();
  }

  // Create auth tokens
  const tokens = await createSession(playerId, env);

  return json({
    playerId,
    displayName: name,
    ...tokens,
  }, 201);
}

async function authLogin(request, env) {
  const raw = await request.json();
  const deviceId = raw.deviceId || raw.device_id;
  const appleUserId = raw.appleUserId || raw.apple_user_id;

  let player;
  if (appleUserId) {
    player = await env.DB.prepare('SELECT id, display_name FROM players WHERE apple_user_id = ?').bind(appleUserId).first();
  }
  if (!player && deviceId) {
    player = await env.DB.prepare('SELECT id, display_name FROM players WHERE device_id = ?').bind(deviceId).first();
  }

  if (!player) return jsonErr('Player not found. Register first.', 404);

  // Update login streak
  await env.DB.prepare(`
    UPDATE players SET last_login_date = datetime('now'), updated_at = datetime('now') WHERE id = ?
  `).bind(player.id).run();

  const tokens = await createSession(player.id, env);

  return json({
    playerId: player.id,
    displayName: player.display_name,
    ...tokens,
  });
}

async function authRefresh(request, env) {
  const raw = await request.json();
  const refreshToken = raw.refreshToken || raw.refresh_token;
  if (!refreshToken) return jsonErr('refreshToken required', 400);

  const session = await env.DB.prepare(
    'SELECT player_id FROM auth_sessions WHERE refresh_token = ?'
  ).bind(refreshToken).first();

  if (!session) return jsonErr('Invalid refresh token', 401);

  // Delete old session
  await env.DB.prepare('DELETE FROM auth_sessions WHERE refresh_token = ?').bind(refreshToken).run();

  // Create new session
  const tokens = await createSession(session.player_id, env);
  return json(tokens);
}

async function createSession(playerId, env) {
  const sessionId = crypto.randomUUID();
  const token = crypto.randomUUID() + '-' + crypto.randomUUID();
  const refreshToken = crypto.randomUUID() + '-' + crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 days

  await env.DB.prepare(`
    INSERT INTO auth_sessions (id, token, player_id, refresh_token, expires_at)
    VALUES (?, ?, ?, ?, ?)
  `).bind(sessionId, token, playerId, refreshToken, expiresAt).run();

  return { token, refreshToken, expiresAt };
}

async function authenticate(request, env) {
  const auth = request.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) return null;

  const token = auth.slice(7);
  const session = await env.DB.prepare(
    "SELECT player_id, expires_at FROM auth_sessions WHERE token = ? AND expires_at > datetime('now')"
  ).bind(token).first();

  if (!session) return null;
  return { id: session.player_id };
}

// ═══════════════════════════════════════════════════
// PLAYER
// ═══════════════════════════════════════════════════

async function getProfile(player, env) {
  const profile = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(player.id).first();
  if (!profile) return jsonErr('Player not found', 404);

  const essences = await env.DB.prepare('SELECT mythology, amount FROM essences WHERE player_id = ?').bind(player.id).all();
  const creatureCount = await env.DB.prepare('SELECT COUNT(*) as count FROM creatures WHERE player_id = ?').bind(player.id).first();
  const uniqueSpecies = await env.DB.prepare('SELECT COUNT(DISTINCT species_id) as count FROM creatures WHERE player_id = ?').bind(player.id).first();

  return json({
    ...profile,
    essences: Object.fromEntries((essences.results || []).map(e => [e.mythology, e.amount])),
    creaturesOwned: creatureCount?.count || 0,
    uniqueSpecies: uniqueSpecies?.count || 0,
  });
}

async function updateProfile(request, player, env) {
  const updates = await request.json();
  const allowed = [
    'display_name', 'avatar_asset', 'level', 'experience', 'title',
    'gold', 'rift_gems', 'rift_dust', 'faction', 'pvp_rating',
    'pvp_wins', 'pvp_losses', 'quests_completed', 'rifts_cleared',
    'territories_claimed', 'total_distance_walked', 'daily_streak',
    'battle_pass_tier', 'battle_pass_premium', 'total_play_time',
  ];

  const sets = [];
  const values = [];
  for (const [key, val] of Object.entries(updates)) {
    const dbKey = key.replace(/([A-Z])/g, '_$1').toLowerCase(); // camelCase → snake_case
    if (allowed.includes(dbKey)) {
      sets.push(`${dbKey} = ?`);
      values.push(val);
    }
  }

  if (sets.length === 0) return jsonErr('No valid fields to update', 400);

  sets.push("updated_at = datetime('now')");
  values.push(player.id);

  await env.DB.prepare(`UPDATE players SET ${sets.join(', ')} WHERE id = ?`).bind(...values).run();

  // Update essences if provided
  if (updates.essences) {
    for (const [myth, amount] of Object.entries(updates.essences)) {
      await env.DB.prepare(`
        INSERT INTO essences (player_id, mythology, amount) VALUES (?, ?, ?)
        ON CONFLICT(player_id, mythology) DO UPDATE SET amount = ?
      `).bind(player.id, myth, amount, amount).run();
    }
  }

  return json({ success: true });
}

async function updateLocation(request, player, env) {
  const { latitude, longitude } = await request.json();
  return json({ newSpawns: [], nearbyTerritories: [], activeEvents: [] });
}

// ═══════════════════════════════════════════════════
// CREATURES
// ═══════════════════════════════════════════════════

async function getCreatures(player, env) {
  const creatures = await env.DB.prepare('SELECT * FROM creatures WHERE player_id = ? ORDER BY created_at DESC')
    .bind(player.id).all();
  return json({ creatures: creatures.results || [] });
}

async function addCreature(request, player, env) {
  const c = toCamel(await request.json());
  const id = c.id || crypto.randomUUID();

  await env.DB.prepare(`
    INSERT INTO creatures (
      id, player_id, species_id, nickname, level, xp, cp, hp,
      attack, defense, speed, iv_hp, iv_attack, iv_defense, iv_speed,
      is_shiny, evolution_stage, caught_latitude, caught_longitude
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).bind(
    id, player.id, c.speciesId, c.nickname || null,
    c.level || 1, c.xp || 0, c.cp || 100, c.hp || 50,
    c.attack || 10, c.defense || 10, c.speed || 10,
    c.ivHp || 0, c.ivAttack || 0, c.ivDefense || 0, c.ivSpeed || 0,
    c.isShiny ? 1 : 0, c.evolutionStage || 1,
    c.caughtLatitude || null, c.caughtLongitude || null
  ).run();

  return json({ id, success: true }, 201);
}

async function evolveCreature(request, player, env) {
  const raw = toCamel(await request.json());
  const creatureId = raw.creatureId;
  const newSpeciesId = raw.newSpeciesId || raw.evolvedSpeciesId;
  const stats = raw.stats || raw.newStats || {};

  const creature = await env.DB.prepare('SELECT * FROM creatures WHERE id = ? AND player_id = ?')
    .bind(creatureId, player.id).first();

  if (!creature) return jsonErr('Creature not found', 404);

  await env.DB.prepare(`
    UPDATE creatures SET
      species_id = ?, level = ?, cp = ?, hp = ?,
      attack = ?, defense = ?, speed = ?,
      evolution_stage = ?
    WHERE id = ? AND player_id = ?
  `).bind(
    newSpeciesId, stats.level || creature.level, stats.cp || creature.cp,
    stats.hp || creature.hp, stats.attack || creature.attack,
    stats.defense || creature.defense, stats.speed || creature.speed,
    stats.evolutionStage || (creature.evolution_stage + 1),
    creatureId, player.id
  ).run();

  return json({ success: true });
}

async function releaseCreature(id, player, env) {
  await env.DB.prepare('DELETE FROM creatures WHERE id = ? AND player_id = ?')
    .bind(id, player.id).run();
  return json({ success: true });
}

// ═══════════════════════════════════════════════════
// INVENTORY
// ═══════════════════════════════════════════════════

async function getInventory(player, env) {
  const items = await env.DB.prepare('SELECT * FROM inventory WHERE player_id = ?')
    .bind(player.id).all();
  return json({ items: items.results || [] });
}

async function addInventoryItem(request, player, env) {
  const item = toCamel(await request.json());
  const itemId = item.itemId || item.id || crypto.randomUUID();

  // Upsert: if same item exists, increment quantity
  const existing = await env.DB.prepare(
    'SELECT id, quantity FROM inventory WHERE player_id = ? AND item_id = ?'
  ).bind(player.id, itemId).first();

  if (existing) {
    await env.DB.prepare('UPDATE inventory SET quantity = quantity + ? WHERE id = ?')
      .bind(item.quantity || 1, existing.id).run();
    return json({ id: existing.id, success: true });
  }

  const id = crypto.randomUUID();
  await env.DB.prepare(`
    INSERT INTO inventory (id, player_id, item_id, item_type, quantity, metadata)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(
    id, player.id, itemId, item.itemType || 'misc',
    item.quantity || 1, item.metadata || null
  ).run();

  return json({ id, success: true }, 201);
}

// ═══════════════════════════════════════════════════
// LEADERBOARD
// ═══════════════════════════════════════════════════

async function getLeaderboard(type, page, env) {
  const limit = 50;
  const offset = page * limit;

  const entries = await env.DB.prepare(`
    SELECT l.player_id, l.score, l.type, p.display_name, p.faction, p.level
    FROM leaderboard l
    JOIN players p ON l.player_id = p.id
    WHERE l.type = ?
    ORDER BY l.score DESC
    LIMIT ? OFFSET ?
  `).bind(type, limit, offset).all();

  const results = (entries.results || []).map((e, i) => ({
    id: e.player_id,
    playerID: e.player_id,
    displayName: e.display_name,
    faction: e.faction,
    level: e.level,
    score: e.score,
    rank: offset + i + 1,
  }));

  return json(results);
}

async function updateLeaderboardScore(playerId, boardType, increment, env) {
  await env.DB.prepare(`
    INSERT INTO leaderboard (id, player_id, type, score, updated_at)
    VALUES (?, ?, ?, ?, datetime('now'))
    ON CONFLICT(player_id, type) DO UPDATE SET score = score + ?, updated_at = datetime('now')
  `).bind(crypto.randomUUID(), playerId, boardType, increment, increment).run();
}

// ═══════════════════════════════════════════════════
// GAME STATE (full save/load for offline sync)
// ═══════════════════════════════════════════════════

async function loadGameState(player, env) {
  const profile = await env.DB.prepare('SELECT * FROM players WHERE id = ?').bind(player.id).first();
  const essences = await env.DB.prepare('SELECT mythology, amount FROM essences WHERE player_id = ?').bind(player.id).all();
  const creatures = await env.DB.prepare('SELECT * FROM creatures WHERE player_id = ?').bind(player.id).all();
  const inventory = await env.DB.prepare('SELECT * FROM inventory WHERE player_id = ?').bind(player.id).all();
  const achievements = await env.DB.prepare('SELECT * FROM achievements WHERE player_id = ?').bind(player.id).all();

  return json({
    player: {
      ...profile,
      essences: Object.fromEntries((essences.results || []).map(e => [e.mythology, e.amount])),
    },
    creatures: creatures.results || [],
    inventory: inventory.results || [],
    achievements: achievements.results || [],
    syncedAt: new Date().toISOString(),
  });
}

async function saveGameState(request, player, env) {
  const state = toCamel(await request.json());

  // Update player profile
  if (state.player) {
    const p = state.player;
    await env.DB.prepare(`
      UPDATE players SET
        level = ?, xp = ?, gold = ?, rift_gems = ?, rift_dust = ?,
        season_tokens = ?, total_catches = ?, total_battles = ?,
        total_distance_km = ?, updated_at = datetime('now')
      WHERE id = ?
    `).bind(
      p.level || 1, p.xp || 0, p.gold || 0, p.riftGems || 0, p.riftDust || 0,
      p.seasonTokens || 0, p.totalCatches || 0, p.totalBattles || 0,
      p.totalDistanceKm || 0, player.id
    ).run();
  }

  // Sync creatures
  if (state.creatures && Array.isArray(state.creatures)) {
    for (const c of state.creatures) {
      await env.DB.prepare(`
        INSERT INTO creatures (id, player_id, species_id, nickname, level, xp, cp, hp, attack, defense, speed,
          iv_hp, iv_attack, iv_defense, iv_speed, is_shiny, evolution_stage, caught_latitude, caught_longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          species_id = ?, level = ?, xp = ?, cp = ?, hp = ?, attack = ?,
          defense = ?, speed = ?, evolution_stage = ?
      `).bind(
        c.id, player.id, c.speciesId, c.nickname || null,
        c.level || 1, c.xp || 0, c.cp || 100, c.hp || 50,
        c.attack || 10, c.defense || 10, c.speed || 10,
        c.ivHp || 0, c.ivAttack || 0, c.ivDefense || 0, c.ivSpeed || 0,
        c.isShiny ? 1 : 0, c.evolutionStage || 1,
        c.caughtLatitude || null, c.caughtLongitude || null,
        // ON CONFLICT updates:
        c.speciesId, c.level || 1, c.xp || 0, c.cp || 100, c.hp || 50,
        c.attack || 10, c.defense || 10, c.speed || 10, c.evolutionStage || 1
      ).run();
    }
  }

  // Sync inventory
  if (state.inventory && Array.isArray(state.inventory)) {
    for (const item of state.inventory) {
      await env.DB.prepare(`
        INSERT INTO inventory (id, player_id, item_id, item_type, quantity)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(player_id, item_id) DO UPDATE SET quantity = ?
      `).bind(
        crypto.randomUUID(), player.id, item.itemId, item.itemType, item.quantity || 1,
        item.quantity || 1
      ).run();
    }
  }

  // Sync leaderboards
  if (state.player) {
    const p = state.player;
    const boards = {
      totalXP: p.xp || 0,
      totalCatches: p.totalCatches || 0,
      totalBattles: p.totalBattles || 0,
      distanceWalked: Math.round(p.totalDistanceKm || 0),
    };
    for (const [type, score] of Object.entries(boards)) {
      await env.DB.prepare(`
        INSERT INTO leaderboard (id, player_id, type, score, updated_at)
        VALUES (?, ?, ?, ?, datetime('now'))
        ON CONFLICT(player_id, type) DO UPDATE SET score = ?, updated_at = datetime('now')
      `).bind(crypto.randomUUID(), player.id, type, score, score).run();
    }
  }

  return json({ success: true, syncedAt: new Date().toISOString() });
}

// ═══════════════════════════════════════════════════
// QUESTS
// ═══════════════════════════════════════════════════

async function getDailyQuests(player, env) {
  // Generate deterministic daily quests based on date
  const today = new Date().toISOString().split('T')[0];
  const seed = hashCode(today + player.id);

  const questPool = [
    { id: `daily_catch_${today}`, title: 'Creature Collector', description: 'Catch 3 creatures today', type: 'daily', objectiveType: 'catchCreature', target: 3, xp: 150, gold: 200 },
    { id: `daily_walk_${today}`, title: 'Rift Walker', description: 'Walk 2 km', type: 'daily', objectiveType: 'walkDistance', target: 2000, xp: 200, gold: 150 },
    { id: `daily_battle_${today}`, title: 'Battle Ready', description: 'Win 2 battles', type: 'daily', objectiveType: 'winBattle', target: 2, xp: 250, gold: 300 },
    { id: `daily_evolve_${today}`, title: 'Evolution Expert', description: 'Evolve a creature', type: 'daily', objectiveType: 'evolveCreature', target: 1, xp: 300, gold: 250 },
  ];

  // Pick 3 quests deterministically
  const selected = [];
  const indices = [Math.abs(seed) % 4, Math.abs(seed * 7) % 4, Math.abs(seed * 13) % 4];
  const used = new Set();
  for (const idx of indices) {
    if (!used.has(idx) && selected.length < 3) {
      used.add(idx);
      selected.push(questPool[idx]);
    }
  }
  // Fill if needed
  for (const q of questPool) {
    if (selected.length >= 3) break;
    if (!selected.includes(q)) selected.push(q);
  }

  return json(selected.slice(0, 3));
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

// ═══════════════════════════════════════════════════
// ESSENCES
// ═══════════════════════════════════════════════════

async function getEssences(player, env) {
  const essences = await env.DB.prepare('SELECT mythology, amount FROM essences WHERE player_id = ?')
    .bind(player.id).all();
  return json(Object.fromEntries((essences.results || []).map(e => [e.mythology, e.amount])));
}

// ═══════════════════════════════════════════════════
// ELEVENLABS TTS PROXY
// ═══════════════════════════════════════════════════

async function elevenLabsTTS(request, env) {
  if (!env.ELEVENLABS_API_KEY) return jsonErr('ElevenLabs not configured', 500);

  const body = await request.json();
  const text = body.text;
  const voiceId = body.voiceId || 'pNInz6obpgDQGcFmaJgB'; // Default: Adam
  const stability = body.stability ?? 0.5;
  const similarityBoost = body.similarityBoost ?? 0.75;
  const style = body.style ?? 0.4;

  if (!text || text.length > 1000) return jsonErr('Text required (max 1000 chars)', 400);

  const resp = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: 'POST',
    headers: {
      'xi-api-key': env.ELEVENLABS_API_KEY,
      'Content-Type': 'application/json',
      'Accept': 'audio/mpeg',
    },
    body: JSON.stringify({
      text,
      model_id: 'eleven_turbo_v2_5',
      voice_settings: {
        stability,
        similarity_boost: similarityBoost,
        style,
        use_speaker_boost: true,
      },
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error('ElevenLabs error:', err);
    return jsonErr(`ElevenLabs error: ${resp.status}`, resp.status);
  }

  return new Response(resp.body, {
    status: 200,
    headers: {
      'Content-Type': 'audio/mpeg',
      ...corsHeaders(),
    },
  });
}

// ═══════════════════════════════════════════════════
// AI COMPANION CHAT (GPT-4o-mini with game context)
// ═══════════════════════════════════════════════════

async function companionChat(request, env) {
  if (!env.OPENAI_API_KEY) return jsonErr('OpenAI not configured', 500);

  const body = await request.json();
  const message = body.message;
  const context = body.context || {};
  const history = body.history || [];

  if (!message) return jsonErr('message required', 400);

  const systemPrompt = `You are Professor Valen, the AI companion guide in RiftWalkers — a Pokemon GO-style mobile game where mythological creatures appear through dimensional rifts in the real world.

PERSONALITY:
- Warm, knowledgeable, slightly mysterious. Like a favorite professor who knows ancient secrets.
- Enthusiastic about mythology but never condescending.
- Speaks naturally and conversationally, like a wise friend walking beside the player.
- Uses short, punchy sentences. Never more than 2-3 sentences.
- Occasionally references Norse, Greek, Egyptian, Japanese, Celtic, Hindu, Aztec, Slavic, Chinese, and African mythology.

GAME KNOWLEDGE:
- Players catch mythological creatures from 10 mythologies via dimensional rifts
- Creatures have elements (fire, water, earth, air, lightning, shadow, light, nature, ice, wind, void, frost, arcane)
- Players level up, evolve creatures, battle PvP, join guilds, complete quests
- Currencies: Gold (soft), Rift Gems (premium), Essences (per-mythology), Rift Dust (crafting)
- Gacha system with pity at 90 pulls

PLAYER CONTEXT:
${context.playerLevel ? `- Level: ${context.playerLevel}` : ''}
${context.creaturesOwned ? `- Creatures owned: ${context.creaturesOwned}` : ''}
${context.currentMythology ? `- Current area mythology: ${context.currentMythology}` : ''}
${context.weather ? `- Weather: ${context.weather}` : ''}
${context.timeOfDay ? `- Time: ${context.timeOfDay}` : ''}
${context.recentEvent ? `- Recent event: ${context.recentEvent}` : ''}

RULES:
- Keep responses under 40 words
- Be helpful and in-character at all times
- If asked about strategy, give genuine tactical advice
- If asked about lore, draw from real mythology
- Never break character or mention being an AI/LLM`;

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.slice(-6), // Keep last 6 messages for context
    { role: 'user', content: message },
  ];

  const resp = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages,
      max_tokens: 120,
      temperature: 0.85,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error('OpenAI error:', err);
    return jsonErr(`AI error: ${resp.status}`, resp.status);
  }

  const data = await resp.json();
  const reply = data.choices?.[0]?.message?.content?.trim() || '';

  return json({ response: reply });
}

// ═══════════════════════════════════════════════════
// OpenAI PROXY (preserved from v1)
// ═══════════════════════════════════════════════════

async function proxyToOpenAI(request, env, targetUrl) {
  if (!env.OPENAI_API_KEY) return jsonErr('Server misconfigured', 500);

  const body = await request.text();
  const resp = await fetch(targetUrl, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
    body,
  });

  return new Response(await resp.text(), {
    status: resp.status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

// ═══════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════

function isRateLimited(deviceId, maxPerMinute) {
  const now = Date.now();
  const entry = rateLimits.get(deviceId);
  if (!entry) { rateLimits.set(deviceId, { count: 1, windowStart: now }); return false; }
  if (now - entry.windowStart > RATE_LIMIT_WINDOW) { entry.count = 1; entry.windowStart = now; return false; }
  entry.count++;
  return entry.count > maxPerMinute;
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Device-ID',
  };
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status, headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

function jsonErr(message, status) {
  return json({ error: { message } }, status);
}

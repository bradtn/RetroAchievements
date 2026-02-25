/**
 * RA Roulette 2026 API Scraper
 *
 * Fetches Roulette data directly from the RA API (no Cloudflare issues!)
 * The event achievements are stored in game ID 37967.
 * DisplayOrder 1-3 = Week 1, 4-6 = Week 2, etc.
 */

const fs = require('fs');
const https = require('https');

const ROULETTE_FILE = 'roulette2026.json';
const RA_API_BASE = 'https://retroachievements.org/API';
const ROULETTE_GAME_ID = 37967;

const RA_USERNAME = process.env.RA_USERNAME;
const RA_API_KEY = process.env.RA_API_KEY;

const EVENT_START = new Date('2026-02-07T00:00:00.000Z');
const WEEK_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        return;
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('Invalid JSON'));
        }
      });
    }).on('error', reject);
  });
}

function getCurrentWeekNumber() {
  const now = new Date();
  const elapsed = now - EVENT_START;
  if (elapsed < 0) return 0;
  return Math.floor(elapsed / WEEK_DURATION_MS) + 1;
}

function getWeekDates(weekNumber) {
  const startDate = new Date(EVENT_START.getTime() + (weekNumber - 1) * WEEK_DURATION_MS);
  const endDate = new Date(startDate.getTime() + WEEK_DURATION_MS - 1);
  return {
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString()
  };
}

async function getAchievementGameDetails(achievementId) {
  // Get the game this achievement belongs to
  const url = `${RA_API_BASE}/API_GetAchievementUnlocks.php?z=${RA_USERNAME}&y=${RA_API_KEY}&a=${achievementId}&c=1`;
  try {
    await sleep(200);
    const data = await fetchJson(url);
    if (data && data.Game) {
      return {
        gameId: data.Game.ID,
        gameTitle: data.Game.Title,
        consoleId: data.Console?.ID || 0,
        consoleName: data.Console?.Title || ''
      };
    }
  } catch (e) {
    console.error(`  Failed to get game for achievement ${achievementId}:`, e.message);
  }
  return null;
}

async function getGameExtended(gameId) {
  const url = `${RA_API_BASE}/API_GetGameExtended.php?z=${RA_USERNAME}&y=${RA_API_KEY}&i=${gameId}`;
  try {
    await sleep(200);
    return await fetchJson(url);
  } catch (e) {
    console.error(`  Failed to get game ${gameId}:`, e.message);
    return null;
  }
}

function getCurrentData() {
  try {
    return JSON.parse(fs.readFileSync(ROULETTE_FILE, 'utf8'));
  } catch (e) {
    return {
      eventName: 'RA Roulette 2026',
      eventId: 200,
      badgeThreshold: 52,
      maxPoints: 156,
      startDate: '2026-02-07T00:00:00.000000Z',
      endDate: '2027-02-06T23:59:59.000000Z',
      weeks: []
    };
  }
}

function isWeekComplete(weekData) {
  if (!weekData || !weekData.achievements) return false;
  if (weekData.achievements.length !== 3) return false;
  return weekData.achievements.every(a =>
    a.achievementId > 0 &&
    a.achievementTitle !== 'TBD' &&
    a.achievementTitle !== 'Placeholder' &&
    a.gameId > 0
  );
}

async function main() {
  console.log('='.repeat(60));
  console.log('RA Roulette 2026 API Scraper');
  console.log('Date:', new Date().toISOString());
  console.log('Current Week:', getCurrentWeekNumber());
  console.log('='.repeat(60));

  if (!RA_USERNAME || !RA_API_KEY) {
    console.error('\nError: RA_USERNAME and RA_API_KEY required');
    process.exit(1);
  }

  console.log('\nCredentials:');
  console.log('  Username:', RA_USERNAME);
  console.log('  API Key: ****' + RA_API_KEY.slice(-4));

  // Fetch the Roulette event achievements
  console.log('\nFetching Roulette 2026 event data (Game ID:', ROULETTE_GAME_ID + ')...');
  const eventData = await getGameExtended(ROULETTE_GAME_ID);

  if (!eventData || !eventData.Achievements) {
    console.error('Failed to fetch event data');
    process.exit(1);
  }

  // Convert achievements object to sorted array
  const achievements = Object.values(eventData.Achievements)
    .sort((a, b) => a.DisplayOrder - b.DisplayOrder);

  console.log('Total achievements in event:', achievements.length);

  const currentWeek = getCurrentWeekNumber();
  const currentData = getCurrentData();

  console.log('\nCurrent JSON weeks:', currentData.weeks?.length || 0);

  // Check which weeks need updating
  const weeksToUpdate = [];
  for (let w = 1; w <= currentWeek; w++) {
    const existingWeek = currentData.weeks?.find(week => week.week === w);
    if (!isWeekComplete(existingWeek)) {
      weeksToUpdate.push(w);
    }
  }

  if (weeksToUpdate.length === 0) {
    console.log('\nAll weeks up to date!');
    return;
  }

  console.log('Weeks needing update:', weeksToUpdate.join(', '));

  // Process each week
  for (const weekNum of weeksToUpdate) {
    console.log(`\nProcessing Week ${weekNum}...`);

    const startOrder = (weekNum - 1) * 3 + 1;
    const weekAchievements = achievements.filter(a =>
      a.DisplayOrder >= startOrder && a.DisplayOrder < startOrder + 3
    );

    if (weekAchievements.length === 0) {
      console.log(`  No achievements found for week ${weekNum}`);
      continue;
    }

    // Check if any are still placeholders
    if (weekAchievements.some(a => a.Title === 'Placeholder')) {
      console.log(`  Week ${weekNum} still has placeholder achievements, skipping`);
      continue;
    }

    console.log(`  Found ${weekAchievements.length} achievements:`);
    weekAchievements.forEach(a => console.log(`    - ${a.ID}: ${a.Title}`));

    const weekDates = getWeekDates(weekNum);
    const processedAchievements = [];

    for (const ach of weekAchievements) {
      console.log(`  Fetching details for ${ach.Title}...`);

      // Get the actual game this achievement belongs to
      const gameInfo = await getAchievementGameDetails(ach.ID);

      if (!gameInfo) {
        console.log(`    Could not get game info, using event data`);
        processedAchievements.push({
          achievementId: ach.ID,
          achievementTitle: ach.Title,
          achievementDescription: ach.Description || '',
          achievementBadgeName: String(ach.BadgeName || '00000'),
          gameId: 0,
          gameTitle: 'Unknown',
          gameImageIcon: '',
          consoleID: 0,
          consoleName: 'Unknown'
        });
        continue;
      }

      // Get extended game data for the image
      const gameExtended = await getGameExtended(gameInfo.gameId);

      processedAchievements.push({
        achievementId: ach.ID,
        achievementTitle: ach.Title,
        achievementDescription: ach.Description || '',
        achievementBadgeName: String(ach.BadgeName || '00000'),
        gameId: gameInfo.gameId,
        gameTitle: gameInfo.gameTitle,
        gameImageIcon: gameExtended?.ImageIcon || '',
        consoleID: gameInfo.consoleId,
        consoleName: gameInfo.consoleName
      });

      console.log(`    -> ${gameInfo.gameTitle} (${gameInfo.consoleName})`);
    }

    // Update week in data
    const existingIndex = currentData.weeks.findIndex(w => w.week === weekNum);
    const weekEntry = {
      week: weekNum,
      startDate: weekDates.startDate,
      endDate: weekDates.endDate,
      achievements: processedAchievements
    };

    if (existingIndex >= 0) {
      currentData.weeks[existingIndex] = weekEntry;
    } else {
      currentData.weeks.push(weekEntry);
    }

    console.log(`  Week ${weekNum} updated with ${processedAchievements.length} achievements`);
  }

  // Sort weeks
  currentData.weeks.sort((a, b) => a.week - b.week);

  // Save
  fs.writeFileSync(ROULETTE_FILE, JSON.stringify(currentData, null, 2));
  console.log('\n' + '='.repeat(60));
  console.log('Saved to', ROULETTE_FILE);
  console.log('='.repeat(60));
}

main().catch(e => {
  console.error('Fatal error:', e.message);
  process.exit(1);
});

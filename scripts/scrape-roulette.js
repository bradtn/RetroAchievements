/**
 * RA Roulette 2026 Scraper
 *
 * Scrapes RA Roulette 2026 weekly achievement data from RetroAchievements.org
 * Uses Puppeteer with stealth plugin to handle Cloudflare protection.
 * Then uses the RA API to get full achievement/game details.
 */

const fs = require('fs');
const https = require('https');

// Try to load puppeteer-extra with stealth, fallback to regular puppeteer
let puppeteer;
let StealthPlugin;
try {
  puppeteer = require('puppeteer-extra');
  StealthPlugin = require('puppeteer-extra-plugin-stealth');
  puppeteer.use(StealthPlugin());
  console.log('Using puppeteer-extra with stealth plugin');
} catch (e) {
  puppeteer = require('puppeteer');
  console.log('Using standard puppeteer (stealth plugin not available)');
}

const ROULETTE_FILE = 'roulette2026.json';
const EVENT_URL = 'https://retroachievements.org/event/200-ra-roulette-2026';
const FORUM_URL = 'https://retroachievements.org/forums/topic/34261';
const RA_API_BASE = 'https://retroachievements.org/API';

// Get credentials from environment
const RA_USERNAME = process.env.RA_USERNAME;
const RA_API_KEY = process.env.RA_API_KEY;

// Event details
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

async function getGameDetails(gameId) {
  if (!RA_USERNAME || !RA_API_KEY) return null;
  const url = `${RA_API_BASE}/API_GetGame.php?z=${RA_USERNAME}&y=${RA_API_KEY}&i=${gameId}`;
  try {
    await sleep(200); // Rate limiting
    return await fetchJson(url);
  } catch (e) {
    console.error(`  Failed to get game ${gameId}:`, e.message);
    return null;
  }
}

async function getGameExtended(gameId) {
  if (!RA_USERNAME || !RA_API_KEY) return null;
  const url = `${RA_API_BASE}/API_GetGameExtended.php?z=${RA_USERNAME}&y=${RA_API_KEY}&i=${gameId}`;
  try {
    await sleep(200); // Rate limiting
    return await fetchJson(url);
  } catch (e) {
    console.error(`  Failed to get extended game ${gameId}:`, e.message);
    return null;
  }
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

async function scrapeEventPage() {
  console.log('Launching browser...');

  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920,1080',
    ],
  });

  try {
    const page = await browser.newPage();

    // Randomize viewport slightly
    const width = 1920 + Math.floor(Math.random() * 100);
    const height = 1080 + Math.floor(Math.random() * 100);
    await page.setViewport({ width, height });

    // Set realistic headers
    await page.setExtraHTTPHeaders({
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });

    console.log('Navigating to RA main site first...');

    // First visit the main site to get cookies
    await page.goto('https://retroachievements.org', {
      waitUntil: 'networkidle2',
      timeout: 60000
    });
    await sleep(3000);

    console.log('Navigating to event page:', EVENT_URL);

    // Now navigate to the event page
    await page.goto(EVENT_URL, {
      waitUntil: 'networkidle2',
      timeout: 60000
    });

    // Wait for potential Cloudflare challenge
    await sleep(5000);

    // Check if we're still on Cloudflare
    let content = await page.content();
    let attempts = 0;
    while ((content.includes('Just a moment') || content.includes('Checking your browser')) && attempts < 3) {
      console.log('Cloudflare challenge detected, waiting... (attempt', attempts + 1, ')');
      await sleep(10000);
      content = await page.content();
      attempts++;
    }

    // Try to get the page title to verify we loaded
    const title = await page.title();
    console.log('Page title:', title);

    if (title.includes('Just a moment') || title.includes('Cloudflare')) {
      throw new Error('Could not bypass Cloudflare protection');
    }

    // Extract achievement data from the page
    const scrapedData = await page.evaluate(() => {
      const results = {
        eventName: '',
        weeks: [],
        allAchievements: [],
        allGames: [],
        rawText: '',
        pageStructure: []
      };

      // Get page text for debugging
      results.rawText = document.body?.innerText?.substring(0, 10000) || '';

      // Try to find event name
      const h1 = document.querySelector('h1');
      if (h1) {
        results.eventName = h1.innerText?.trim() || '';
      }

      // Find ALL achievement and game links on the page
      document.querySelectorAll('a').forEach(link => {
        const href = link.getAttribute('href') || '';
        const text = link.innerText?.trim() || '';

        // Achievement links
        const achMatch = href.match(/\/achievement\/(\d+)/);
        if (achMatch) {
          results.allAchievements.push({
            id: parseInt(achMatch[1]),
            text: text.substring(0, 100),
            href: href
          });
        }

        // Game links
        const gameMatch = href.match(/\/game\/(\d+)/);
        if (gameMatch) {
          results.allGames.push({
            id: parseInt(gameMatch[1]),
            text: text.substring(0, 100),
            href: href
          });
        }
      });

      // Look for week-based sections
      // The event page typically shows achievements grouped by week
      const weekSections = document.querySelectorAll('[class*="week"], [data-week], table tr, .card');
      weekSections.forEach(section => {
        const text = section.innerText || '';
        const weekMatch = text.match(/Week\s*(\d+)/i);
        if (weekMatch) {
          const weekNum = parseInt(weekMatch[1]);
          const achievements = [];

          section.querySelectorAll('a').forEach(link => {
            const href = link.getAttribute('href') || '';
            const achMatch = href.match(/\/achievement\/(\d+)/);
            if (achMatch) {
              achievements.push({
                id: parseInt(achMatch[1]),
                text: link.innerText?.trim() || ''
              });
            }
          });

          if (achievements.length > 0) {
            results.weeks.push({
              week: weekNum,
              achievements: achievements
            });
          }
        }
      });

      // Deduplicate achievements
      const uniqueAch = {};
      results.allAchievements.forEach(a => { uniqueAch[a.id] = a; });
      results.allAchievements = Object.values(uniqueAch);

      // Deduplicate games
      const uniqueGame = {};
      results.allGames.forEach(g => { uniqueGame[g.id] = g; });
      results.allGames = Object.values(uniqueGame);

      // Deduplicate weeks
      const uniqueWeeks = {};
      results.weeks.forEach(w => {
        if (!uniqueWeeks[w.week] || w.achievements.length > uniqueWeeks[w.week].achievements.length) {
          uniqueWeeks[w.week] = w;
        }
      });
      results.weeks = Object.values(uniqueWeeks).sort((a, b) => a.week - b.week);

      return results;
    });

    console.log('\n=== Event Page Scrape Results ===');
    console.log('Event name:', scrapedData.eventName);
    console.log('Weeks found:', scrapedData.weeks.length);
    console.log('Total achievement links:', scrapedData.allAchievements.length);
    console.log('Total game links:', scrapedData.allGames.length);

    if (scrapedData.weeks.length > 0) {
      console.log('\nWeeks data:');
      scrapedData.weeks.forEach(w => {
        console.log(`  Week ${w.week}: ${w.achievements.length} achievements`);
        w.achievements.forEach(a => {
          console.log(`    - ${a.id}: ${a.text}`);
        });
      });
    }

    // Save screenshot for debugging
    try {
      await page.screenshot({ path: '/tmp/ra-roulette-page.png', fullPage: true });
      console.log('\nScreenshot saved to /tmp/ra-roulette-page.png');
    } catch (e) {
      console.log('Could not save screenshot:', e.message);
    }

    // Also try the forum page for more detailed weekly info
    console.log('\nNavigating to forum page:', FORUM_URL);
    await page.goto(FORUM_URL, {
      waitUntil: 'networkidle2',
      timeout: 60000
    });
    await sleep(3000);

    const forumData = await page.evaluate(() => {
      const results = {
        weeks: [],
        rawText: document.body?.innerText?.substring(0, 20000) || ''
      };

      // Forum posts often have more detailed week info
      // Look for patterns like "Week X achievements" or weekly posts
      const posts = document.querySelectorAll('.post, .comment, article, [class*="post"]');
      posts.forEach(post => {
        const text = post.innerText || '';
        const weekMatches = text.matchAll(/Week\s*(\d+)[:\s]*([\s\S]*?)(?=Week\s*\d+|$)/gi);

        for (const match of weekMatches) {
          const weekNum = parseInt(match[1]);
          const weekText = match[2];
          const achievements = [];

          // Find achievement IDs in this week's text
          post.querySelectorAll('a').forEach(link => {
            const href = link.getAttribute('href') || '';
            const achMatch = href.match(/\/achievement\/(\d+)/);
            if (achMatch) {
              achievements.push({
                id: parseInt(achMatch[1]),
                text: link.innerText?.trim() || ''
              });
            }
          });

          if (achievements.length > 0) {
            results.weeks.push({
              week: weekNum,
              achievements: achievements
            });
          }
        }
      });

      return results;
    });

    console.log('\n=== Forum Page Scrape Results ===');
    console.log('Forum weeks found:', forumData.weeks.length);

    // Merge forum data with event page data
    forumData.weeks.forEach(fw => {
      const existing = scrapedData.weeks.find(w => w.week === fw.week);
      if (!existing) {
        scrapedData.weeks.push(fw);
      } else if (fw.achievements.length > existing.achievements.length) {
        existing.achievements = fw.achievements;
      }
    });

    scrapedData.weeks.sort((a, b) => a.week - b.week);

    // Save forum screenshot
    try {
      await page.screenshot({ path: '/tmp/ra-roulette-forum.png', fullPage: true });
      console.log('Forum screenshot saved to /tmp/ra-roulette-forum.png');
    } catch (e) {
      console.log('Could not save forum screenshot:', e.message);
    }

    await browser.close();
    return scrapedData;

  } catch (error) {
    console.error('Scraping error:', error.message);
    try {
      await browser.close();
    } catch (e) {}
    throw error;
  }
}

async function buildAchievementEntry(achievementId) {
  console.log(`  Fetching achievement ${achievementId}...`);

  // First we need to find which game this achievement belongs to
  // Use the API to get achievement info
  if (!RA_USERNAME || !RA_API_KEY) return null;

  const achUrl = `${RA_API_BASE}/API_GetAchievementUnlocks.php?z=${RA_USERNAME}&y=${RA_API_KEY}&a=${achievementId}&c=1`;

  try {
    await sleep(200);
    const achData = await fetchJson(achUrl);

    if (!achData || !achData.Game) {
      console.error(`    Could not get achievement ${achievementId} details`);
      return null;
    }

    const gameId = achData.Game.ID;
    const gameExtended = await getGameExtended(gameId);

    if (!gameExtended) {
      console.error(`    Could not get game ${gameId} extended data`);
      return null;
    }

    // Find the achievement in the game's achievement list
    let achievement = null;
    if (gameExtended.Achievements) {
      achievement = Object.values(gameExtended.Achievements).find(
        a => String(a.ID) === String(achievementId)
      );
    }

    if (!achievement) {
      console.error(`    Could not find achievement ${achievementId} in game data`);
      return null;
    }

    console.log(`    Found: ${achievement.Title} - ${achData.Game.Title}`);

    return {
      achievementId: parseInt(achievementId),
      achievementTitle: achievement.Title || '',
      achievementDescription: achievement.Description || '',
      achievementBadgeName: String(achievement.BadgeName || '00000'),
      gameId: parseInt(gameId),
      gameTitle: achData.Game.Title || '',
      gameImageIcon: gameExtended.ImageIcon || '',
      consoleID: parseInt(achData.Console?.ID || gameExtended.ConsoleID || 0),
      consoleName: achData.Console?.Title || gameExtended.ConsoleName || ''
    };
  } catch (e) {
    console.error(`    Error fetching achievement ${achievementId}:`, e.message);
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

function isWeekDataComplete(weekData) {
  if (!weekData || !weekData.achievements) return false;
  if (weekData.achievements.length !== 3) return false;

  // Check if all achievements have real data (not TBD)
  return weekData.achievements.every(a =>
    a.achievementId > 0 &&
    a.achievementTitle !== 'TBD' &&
    a.gameId > 0
  );
}

async function main() {
  console.log('='.repeat(60));
  console.log('RetroAchievements Roulette 2026 Scraper');
  console.log('Date:', new Date().toISOString());
  console.log('Current Week:', getCurrentWeekNumber());
  console.log('='.repeat(60));

  if (!RA_USERNAME || !RA_API_KEY) {
    console.error('\n*** ERROR: RA_USERNAME and RA_API_KEY required ***');
    console.log('Add these as repository secrets in GitHub:');
    console.log('  Settings -> Secrets and variables -> Actions -> New repository secret');
    console.log('  RA_USERNAME: Your RetroAchievements username');
    console.log('  RA_API_KEY: Your API key from https://retroachievements.org/settings');
    process.exit(1);
  }

  console.log('\nCredentials:');
  console.log('  Username:', RA_USERNAME);
  console.log('  API Key: ****' + RA_API_KEY.slice(-4));

  // Load current data
  const currentData = getCurrentData();
  const currentWeek = getCurrentWeekNumber();

  console.log('\nCurrent data:');
  console.log('  Weeks in JSON:', currentData.weeks?.length || 0);

  // Check which weeks need updating
  const weeksNeedingUpdate = [];
  for (let w = 1; w <= currentWeek; w++) {
    const weekData = currentData.weeks?.find(week => week.week === w);
    if (!isWeekDataComplete(weekData)) {
      weeksNeedingUpdate.push(w);
    }
  }

  console.log('  Weeks needing update:', weeksNeedingUpdate.join(', ') || 'None');

  if (weeksNeedingUpdate.length === 0) {
    console.log('\n*** All weeks are up to date! ***');
    return;
  }

  try {
    // Scrape the event page
    const scrapedData = await scrapeEventPage();

    console.log('\n=== Processing Scraped Data ===');

    let updated = false;

    for (const weekNum of weeksNeedingUpdate) {
      const scrapedWeek = scrapedData.weeks.find(w => w.week === weekNum);

      if (!scrapedWeek || scrapedWeek.achievements.length < 3) {
        console.log(`\nWeek ${weekNum}: Insufficient data scraped (found ${scrapedWeek?.achievements?.length || 0} achievements)`);
        continue;
      }

      console.log(`\nProcessing Week ${weekNum}...`);

      const weekDates = getWeekDates(weekNum);
      const achievements = [];

      for (const scrapedAch of scrapedWeek.achievements.slice(0, 3)) {
        const achEntry = await buildAchievementEntry(scrapedAch.id);
        if (achEntry) {
          achievements.push(achEntry);
        } else {
          // Create placeholder if API call failed
          achievements.push({
            achievementId: scrapedAch.id,
            achievementTitle: scrapedAch.text || 'Unknown',
            achievementDescription: '',
            achievementBadgeName: '00000',
            gameId: 0,
            gameTitle: 'Unknown',
            gameImageIcon: '',
            consoleID: 0,
            consoleName: 'Unknown'
          });
        }
      }

      // Update or add week in current data
      const existingWeekIndex = currentData.weeks.findIndex(w => w.week === weekNum);
      const weekEntry = {
        week: weekNum,
        startDate: weekDates.startDate,
        endDate: weekDates.endDate,
        achievements: achievements
      };

      if (existingWeekIndex >= 0) {
        currentData.weeks[existingWeekIndex] = weekEntry;
      } else {
        currentData.weeks.push(weekEntry);
      }

      updated = true;
      console.log(`  Week ${weekNum} updated with ${achievements.length} achievements`);
    }

    // Sort weeks
    currentData.weeks.sort((a, b) => a.week - b.week);

    if (updated) {
      // Save updated JSON
      fs.writeFileSync(ROULETTE_FILE, JSON.stringify(currentData, null, 2));
      console.log('\n*** Updated', ROULETTE_FILE, '***');
    } else {
      console.log('\n*** No updates made ***');
    }

    console.log('\n' + '='.repeat(60));
    console.log('Scrape complete');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n*** Scraping failed ***');
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();

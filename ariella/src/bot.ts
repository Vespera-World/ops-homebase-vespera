import express from 'express';
import TelegramBot from 'node-telegram-bot-api';
import { createClient } from '@supabase/supabase-js';
import { config } from './config';
import { askLLM } from './agent';

const app = express();
app.use(express.json());

const bot = new TelegramBot(config.telegramToken);
const supabase = createClient(config.supabaseUrl, config.supabaseKey);

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', agent: 'ariella', version: '1.0.0' });
});

// Webhook endpoint for Telegram
app.post('/webhook', async (req, res) => {
  try {
    const update = req.body;
    if (!update.message && !update.callback_query) {
      res.sendStatus(200);
      return;
    }

    const msg = update.message;
    const chatId = msg?.chat?.id?.toString();
    const text = msg?.text || '';
    const userId = msg?.from?.id?.toString();
    const userName = msg?.from?.first_name || 'Creator';

    // Auth check
    if (config.allowedChats.length > 0 && chatId && !config.allowedChats.includes(chatId)) {
      console.log(`Blocked chat: ${chatId}`);
      res.sendStatus(200);
      return;
    }

    console.log(`[${chatId}] ${userName}: ${text}`);

    // Fetch creator context from Supabase (read-only)
    let creatorContext = '';
    try {
      const { data: creators } = await supabase
        .from('clients')
        .select('name, status, monthly_revenue, platform')
        .eq('telegram_chat_id', chatId)
        .limit(1);
      if (creators && creators.length > 0) {
        const c = creators[0];
        creatorContext = `Known creator: ${c.name}, status: ${c.status}, platform: ${c.platform}, revenue: $${c.monthly_revenue}`;
      }
    } catch (e) {
      // Supabase might not have telegram_chat_id column yet
      console.log('Supabase lookup skipped:', (e as Error).message);
    }

    // Build message for LLM
    const llmMessages = [
      ...(creatorContext ? [{ role: 'system', content: `Context: ${creatorContext}` }] : []),
      { role: 'user', content: `${userName}: ${text}` },
    ];

    const reply = await askLLM(llmMessages);

    // Send reply via Telegram
    await bot.sendMessage(chatId, reply, { parse_mode: 'Markdown' });

    res.sendStatus(200);
  } catch (err) {
    console.error('Webhook error:', err);
    res.sendStatus(500);
  }
});

// Set webhook on startup
async function start() {
  app.listen(config.port, async () => {
    console.log(`Ariella listening on port ${config.port}`);

    if (config.webhookUrl) {
      try {
        await bot.setWebHook(`${config.webhookUrl}/webhook`);
        console.log(`Webhook set to ${config.webhookUrl}/webhook`);
      } catch (err) {
        console.error('Failed to set webhook:', err);
      }
    } else {
      console.log('No WEBHOOK_URL set — webhook not registered');
    }
  });
}

start();

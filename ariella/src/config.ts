import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || 3000,
  telegramToken: process.env.TELEGRAM_BOT_TOKEN!,
  webhookUrl: process.env.WEBHOOK_URL!,
  supabaseUrl: process.env.SUPABASE_URL!,
  supabaseKey: process.env.SUPABASE_ANON_KEY!,
  llm: {
    provider: process.env.LLM_PROVIDER || 'openrouter',
    apiKey: process.env.OPENROUTER_API_KEY!,
    model: process.env.LLM_MODEL || 'anthropic/claude-sonnet-4',
    baseUrl: process.env.LLM_BASE_URL || 'https://openrouter.ai/api/v1',
  },
  allowedChats: process.env.ALLOWED_CHATS?.split(',').map(s => s.trim()) || [],
  n8nWebhook: process.env.N8N_WEBHOOK_URL,
};

if (!config.telegramToken) throw new Error('TELEGRAM_BOT_TOKEN required');
if (!config.supabaseUrl) throw new Error('SUPABASE_URL required');
if (!config.llm.apiKey) throw new Error('OPENROUTER_API_KEY required');

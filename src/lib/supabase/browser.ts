"use client";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

// Supabase-Zugang im Browser mit dem öffentlichen anon-Schlüssel.
// Der darf dank Row Level Security nur Räume und Spieler lesen.
let client: SupabaseClient | null = null;

export function supabaseBrowser(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  client ??= createClient(url, key, { auth: { persistSession: false } });
  return client;
}

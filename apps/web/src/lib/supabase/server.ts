import { createServerClient, type CookieOptions } from '@supabase/ssr';

// ...
setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
  try {
    cookiesToSet.forEach(({ name, value, options }) => {
      cookieStore.set(name, value, options);
    });
  } catch {
    // ...
  }
}

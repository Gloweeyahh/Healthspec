import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  darkMode: ["class"],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: "var(--color-brand-primary)",
        },
        neutral: {
          950: "var(--color-neutral-950)",
          900: "var(--color-neutral-900)",
          800: "var(--color-neutral-800)",
          700: "var(--color-neutral-700)",
          600: "var(--color-neutral-600)",
          500: "var(--color-neutral-500)",
          400: "var(--color-neutral-400)",
          300: "var(--color-neutral-300)",
          200: "var(--color-neutral-200)",
          100: "var(--color-neutral-100)",
          50: "var(--color-neutral-50)",
        },
        success: "var(--color-success)",
        warning: "var(--color-warning)",
        error: "var(--color-error)",
        info: "var(--color-info)",
      },
      borderRadius: {
        sm: "var(--radius-sm)",
        md: "var(--radius-md)",
        lg: "var(--radius-lg)",
        xl: "var(--radius-xl)",
      },
    },
  },
  plugins: [],
};

export default config;

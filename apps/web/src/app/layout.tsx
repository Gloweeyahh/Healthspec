import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HealthSpec",
  description:
    "A developer-facing interoperability and conformance laboratory for health APIs.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

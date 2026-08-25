import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: { default: 'SourceEnergy Media', template: '%s | SourceEnergy Media' },
  description: 'Governed media, research, intelligence and institutional communications across the SourceEnergy ecosystem.'
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#main-content">Skip to content</a>
        <header className="site-header">
          <div className="shell">
            <a className="brand" href="/">SourceEnergy Media</a>
            <nav aria-label="Primary">
              <a href="/news">News</a>
              <a href="/intelligence">Intelligence</a>
              <a href="/research">Research</a>
              <a href="/publications">Publications</a>
              <a href="/press">Press Room</a>
            </nav>
          </div>
        </header>
        <main id="main-content">{children}</main>
        <footer className="site-footer"><div className="shell">SourceEnergy Media & Communications</div></footer>
      </body>
    </html>
  );
}

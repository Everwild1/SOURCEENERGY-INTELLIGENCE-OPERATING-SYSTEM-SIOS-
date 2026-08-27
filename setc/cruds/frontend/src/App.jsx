import { useEffect, useMemo, useState } from "react";
import { loadUniverse } from "./data/cruds-client.js";

const LANE_COPY = {
  works: ["Works & portfolios", "Published work records, contributors and media, without overstating authorship."],
  witness: ["Authorship & Witness Grid", "Evidence requests and authority confirmations remain references to the approved verifier."],
  opportunities: ["Opportunities", "Discover commissions, collaborations and funding; every response remains non-binding."],
  commercialization: ["Commercialization", "Move a work from discovery to readiness with explicit provenance at every stage."],
  market: ["WIM market access", "Request access into WIM Exchange while WIM retains workflow and transaction authority."],
  research: ["Research & publications", "Connect creative work to source-backed knowledge and publication records."],
  settlement: ["Settlement boundary", "Track orchestration references only. External rails retain finality and ledger authority."],
  intelligence: ["Wealth Ecology intelligence", "Read methodology-versioned projections with evidence, confidence and correction history."],
};

function StatusPill({ children, tone = "neutral" }) {
  return <span className={`status status--${tone}`}>{children}</span>;
}

function Header({ menuOpen, onMenuToggle }) {
  return (
    <header className="site-header">
      <a className="skip-link" href="#main">Skip to content</a>
      <div className="masthead">
        <a className="wordmark" href="#top" aria-label="CRUDS Universe home">CRUDS UNIVERSE</a>
        <p>Creatives, Underwriters &amp; Developers Universe</p>
      </div>
      <button className="menu-button" type="button" aria-expanded={menuOpen} aria-controls="main-nav" onClick={onMenuToggle}>
        {menuOpen ? "Close menu" : "Menu"}
      </button>
      <nav id="main-nav" className={menuOpen ? "main-nav main-nav--open" : "main-nav"} aria-label="Primary navigation">
        <a href="#wall">The Wall of Creatives</a>
        <a href="#operating-loop">Our Platform</a>
        <a href="#opportunities">Opportunities</a>
        <a href="#intelligence">Intelligence</a>
        <a href="#principles">Manifesto</a>
      </nav>
    </header>
  );
}

function Hero({ stats, dataMode }) {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="hero__copy">
        <p className="eyebrow">The Wall of Creatives · {dataMode === "preview" ? "Preview data" : "Live registry"}</p>
        <h1 id="hero-title">Life’s work,<br /><em>seen &amp; heard.</em></h1>
        <p className="hero__lede">A governed universe where creative identity, original work and durable value can meet—without confusing a platform record for legal, market or financial authority.</p>
        <div className="hero__actions">
          <a className="button button--primary" href="#wall">Explore the wall</a>
          <a className="button button--text" href="#operating-loop">How the universe works</a>
        </div>
      </div>
      <div className="hero__visual">
        <div className="hero__image-frame">
          <img src="/assets/wall-of-creatives.png" alt="Illustrated panorama of creative disciplines from florist and musician to filmmaker and videographer" />
        </div>
        <div className="hero__stats" aria-label="Universe overview">
          <div><strong>{stats.creators}</strong><span>creators</span></div>
          <div><strong>{stats.works}</strong><span>published works</span></div>
          <div><strong>6</strong><span>archetypes</span></div>
        </div>
      </div>
    </section>
  );
}

function ArchetypeFilter({ archetypes, selected, onSelect }) {
  return (
    <div className="archetype-filter" aria-label="Filter creators by archetype">
      <button className={selected === "all" ? "is-active" : ""} type="button" onClick={() => onSelect("all")}>All creatives</button>
      {archetypes.map((item) => (
        <button key={item.code} className={selected === item.code ? "is-active" : ""} type="button" onClick={() => onSelect(item.code)}>
          <span>{item.name}</span><small>{item.shortDescription}</small>
        </button>
      ))}
    </div>
  );
}

function CreatorCard({ creator, onSelect }) {
  return (
    <article className="creator-card">
      <div className="creator-card__number" aria-hidden="true">{String(creator.wallOrder).padStart(2, "0")}</div>
      <div className="creator-card__body">
        <div className="creator-card__meta">
          <span>{creator.location}</span>
          <StatusPill tone="magenta">The {creator.primaryArchetype}</StatusPill>
        </div>
        <h3>{creator.displayName}</h3>
        <p>{creator.headline}</p>
        <div className="creator-card__footer">
          <span>{creator.workCount} works</span>
          <button type="button" onClick={() => onSelect(creator)}>View profile</button>
        </div>
      </div>
    </article>
  );
}

function CreatorDetail({ creator, works, onClose }) {
  if (!creator) return null;
  const creatorWorks = works.filter((work) => work.creatorId === creator.id);
  return (
    <div className="detail-overlay" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="detail-panel" role="dialog" aria-modal="true" aria-labelledby="creator-detail-title">
        <button className="detail-panel__close" type="button" onClick={onClose}>Close</button>
        <p className="eyebrow">Creator profile · identity projection</p>
        <h2 id="creator-detail-title">{creator.displayName}</h2>
        <p className="detail-panel__headline">{creator.headline}</p>
        <div className="detail-panel__facts">
          <div><span>Primary archetype</span><strong>{creator.primaryArchetype}</strong></div>
          <div><span>Identity reference</span><strong>{creator.identityReference}</strong></div>
          <div><span>Profile state</span><strong>Published</strong></div>
        </div>
        <p>{creator.biography}</p>
        <div className="detail-panel__works">
          <h3>Selected work</h3>
          {creatorWorks.map((work) => (
            <article key={work.id}>
              <div><StatusPill tone={work.verificationStatus === "verified" ? "green" : "neutral"}>{work.verificationStatus}</StatusPill><span>{work.workType}</span></div>
              <h4>{work.title}</h4>
              <p>{work.summary}</p>
            </article>
          ))}
        </div>
        <p className="boundary-note">Creator identity is a projection from an approved identity authority. Archetypes support discovery and confer no licence, credential or legal status.</p>
      </section>
    </div>
  );
}

function OperatingLoop() {
  const steps = ["Creator", "Work", "Provenance", "Discovery", "Commercialization", "WIM access", "Impact reference", "Intelligence"];
  return (
    <section id="operating-loop" className="loop-section section-shell" aria-labelledby="loop-title">
      <div className="section-heading section-heading--split">
        <div><p className="eyebrow">One governed operating loop</p><h2 id="loop-title">From creative spark to durable value.</h2></div>
        <p>Each handoff keeps its authority boundary visible, so evidence, opportunity and economic impact can connect without collapsing into one system.</p>
      </div>
      <ol className="loop">
        {steps.map((step, index) => <li key={step}><span>{String(index + 1).padStart(2, "0")}</span><strong>{step}</strong></li>)}
      </ol>
      <img className="loop-art" src="/assets/wall-platform.png" alt="The Wall of Creatives platform continuum connecting creative stages and ecosystem services" />
    </section>
  );
}

function ContractLanes() {
  return (
    <section className="lanes section-shell" aria-labelledby="lanes-title">
      <div className="section-heading"><p className="eyebrow">E01–E08 connected</p><h2 id="lanes-title">One public experience. Clear sources of authority.</h2></div>
      <div className="lane-grid">
        {Object.entries(LANE_COPY).map(([key, [title, copy]], index) => (
          <article className="lane" key={key}>
            <span>{String(index + 1).padStart(2, "0")}</span>
            <h3>{title}</h3>
            <p>{copy}</p>
            <a href={key === "intelligence" ? "#intelligence" : key === "opportunities" ? "#opportunities" : "#principles"}>Read the boundary</a>
          </article>
        ))}
      </div>
    </section>
  );
}

function OpportunitySection({ opportunities }) {
  const [selected, setSelected] = useState(opportunities[0]?.id ?? null);
  const [interestCaptured, setInterestCaptured] = useState(null);
  const active = opportunities.find((item) => item.id === selected) ?? opportunities[0];
  return (
    <section id="opportunities" className="opportunity-section section-shell" aria-labelledby="opportunities-title">
      <div className="section-heading section-heading--split">
        <div><p className="eyebrow">Open calls</p><h2 id="opportunities-title">Find the next useful collision.</h2></div>
        <p>Explore collaboration and commercialization signals. Expressing interest records a non-binding response—it does not create a contract or transaction.</p>
      </div>
      <div className="opportunity-layout">
        <div className="opportunity-list" role="tablist" aria-label="Open opportunities">
          {opportunities.map((item) => (
            <button key={item.id} role="tab" aria-selected={active?.id === item.id} className={active?.id === item.id ? "is-active" : ""} onClick={() => setSelected(item.id)}>
              <span>{item.type}</span><strong>{item.title}</strong><small>{item.closesLabel}</small>
            </button>
          ))}
        </div>
        {active && <article className="opportunity-detail" role="tabpanel">
          <div className="opportunity-detail__top"><StatusPill tone="green">{active.status}</StatusPill><span>{active.type}</span></div>
          <h3>{active.title}</h3>
          <p>{active.description}</p>
          <dl>
            <div><dt>Creative lane</dt><dd>{active.archetype}</dd></div>
            <div><dt>Linked work</dt><dd>{active.workTitle}</dd></div>
            <div><dt>Closes</dt><dd>{active.closesLabel}</dd></div>
          </dl>
          <button className="button button--primary" type="button" disabled={interestCaptured === active.id} onClick={() => setInterestCaptured(active.id)}>{interestCaptured === active.id ? "Interest noted" : "Express interest"}</button>
          <p className="microcopy" aria-live="polite">{interestCaptured === active.id ? "Local preview saved. No information was transmitted." : "Preview only · no contract, transaction or settlement is created."}</p>
        </article>}
      </div>
    </section>
  );
}

function IntelligenceSection({ intelligence, research }) {
  return (
    <section id="intelligence" className="intelligence section-shell" aria-labelledby="intelligence-title">
      <div className="section-heading section-heading--split">
        <div><p className="eyebrow">Wealth Ecology intelligence</p><h2 id="intelligence-title">Measure what creative work makes possible.</h2></div>
        <p>Every projection is methodology-versioned, evidence-backed and explicitly distinct from authoritative transaction or settlement state.</p>
      </div>
      <div className="metrics-grid">
        {intelligence.map((item) => (
          <article key={item.code}>
            <span>{item.label}</span><strong>{item.value}</strong><small>{item.context}</small>
            <div className="metric-meta"><span>{item.methodologyVersion}</span><span>{item.measurementKind}</span></div>
          </article>
        ))}
      </div>
      <div className="research-strip">
        <div><p className="eyebrow">Research &amp; publications</p><h3>Sources behind the signal</h3></div>
        <div className="research-list">
          {research.map((item) => <article key={item.id}><span>{item.dateLabel}</span><h4>{item.title}</h4><p>{item.source}</p></article>)}
        </div>
      </div>
    </section>
  );
}

function Principles() {
  return (
    <section id="principles" className="principles section-shell" aria-labelledby="principles-title">
      <img src="/assets/six-stage-continuum.png" alt="Six-stage continuum from ideation and research through capitalization" />
      <div>
        <p className="eyebrow">About CRUDS Universe</p>
        <h2 id="principles-title">Not a marketplace.<br />Not a social platform.<br /><em>Digital economic infrastructure.</em></h2>
        <p>We provide the provenance, governance and coordination layer that lets creators, backers and builders work together without extraction, opacity or centralized control.</p>
        <ul><li>Creativity is treated as infrastructure.</li><li>Governance is embedded, not optional.</li><li>Value is distributed by design.</li></ul>
      </div>
    </section>
  );
}

export function App() {
  const [universe, setUniverse] = useState(null);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState("all");
  const [selectedCreator, setSelectedCreator] = useState(null);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    loadUniverse().then(setUniverse).catch(() => setError("The universe could not be loaded. Please try again."));
  }, []);

  useEffect(() => {
    if (!selectedCreator) return undefined;
    const previousOverflow = document.body.style.overflow;
    const onKeyDown = (event) => event.key === "Escape" && setSelectedCreator(null);
    document.body.style.overflow = "hidden";
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [selectedCreator]);

  const creators = useMemo(() => {
    if (!universe) return [];
    return filter === "all" ? universe.creators : universe.creators.filter((creator) => creator.archetypes.includes(filter));
  }, [filter, universe]);

  if (error) return <main className="state-message"><p className="eyebrow">CRUDS Universe</p><h1>{error}</h1></main>;
  if (!universe) return <main className="state-message" aria-live="polite"><p className="eyebrow">CRUDS Universe</p><h1>Opening the wall…</h1></main>;

  return (
    <div id="top">
      <Header menuOpen={menuOpen} onMenuToggle={() => setMenuOpen((value) => !value)} />
      <main id="main">
        <Hero stats={universe.stats} dataMode={universe.dataMode} />
        <section id="wall" className="wall section-shell" aria-labelledby="wall-title">
          <div className="section-heading section-heading--split">
            <div><p className="eyebrow">The Wall of Creatives</p><h2 id="wall-title">Six ways of moving an idea forward.</h2></div>
            <p>Archetypes are capability and discovery classifications—not identity, accreditation or ownership claims.</p>
          </div>
          <ArchetypeFilter archetypes={universe.archetypes} selected={filter} onSelect={setFilter} />
          <div className="creator-grid" aria-live="polite">
            {creators.map((creator) => <CreatorCard key={creator.id} creator={creator} onSelect={setSelectedCreator} />)}
          </div>
        </section>
        <OperatingLoop />
        <ContractLanes />
        <OpportunitySection opportunities={universe.opportunities} />
        <IntelligenceSection intelligence={universe.intelligence} research={universe.research} />
        <Principles />
      </main>
      <footer><a className="wordmark wordmark--footer" href="#top">CRUDS UNIVERSE</a><p>© 2026 Underwritten by SourceEnergy™</p><p>Creativity protected. Authority made visible.</p></footer>
      <CreatorDetail creator={selectedCreator} works={universe.works} onClose={() => setSelectedCreator(null)} />
    </div>
  );
}

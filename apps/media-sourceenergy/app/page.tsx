const desks = ['News','Intelligence','Research','Business','Trade','Capital','Technology','Energy','Infrastructure','Health','Education','Diaspora','Climate','Government'];

export default function HomePage() {
  return (
    <div className="shell page-stack">
      <section className="hero" aria-labelledby="media-heading">
        <p className="eyebrow">SourceEnergy Media & Communications</p>
        <h1 id="media-heading">Governed information for a connected economic ecosystem.</h1>
        <p className="lede">News, research, intelligence, publications and institutional communications with evidence, approval and correction controls built into the operating model.</p>
      </section>
      <section aria-labelledby="desks-heading">
        <h2 id="desks-heading">Network desks</h2>
        <div className="route-grid">
          {desks.map((desk) => <a className="route-card" key={desk} href={`/${desk.toLowerCase()}`}>{desk}</a>)}
        </div>
      </section>
      <section className="boundary" aria-labelledby="trust-heading">
        <h2 id="trust-heading">Publication integrity</h2>
        <p>Published Media records communicate approved information; they do not independently create legal, financial, regulatory, governmental, scientific, partnership or transaction authority.</p>
      </section>
    </div>
  );
}

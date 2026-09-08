# 💹 Business Model

SponsoredLogs operates a **two-sided exchange** at the intersection of two
hockey sticks — the log-management market (billions) and the digital-advertising
market (hundreds of billions). We sit in the middle and take a cut of the
compression.

## The core unit economics

Everything ladders up to **eLPM** — *effective Log-line Per Mille*, our
proprietary north-star yield metric. Every emitted line is one unit of
inventory. At a conservative 1-in-1000 fill rate and an industry-blended CPM, a
mid-size fleet emitting 1B lines/day is sitting on a **seven-figure annual yield
surface it is currently expensing as a cost center.** We turn that cost line
into a revenue line. The delta is the business.

## Revenue streams

1. **Programmatic placements (CPM).** Advertisers bid for inventory; the
   exchange fills at market rate. Weighted and CPM auction modes are live today.
   We take a platform fee on cleared spend — the standard exchange rake, and,
   candidly, a bargain.

2. **Impact-tier upsell.** Banner inventory is sold in three tiers — `:light`,
   `:heavy`, `:double`. Advertisers don't want a placement; they want *impact*,
   and impact is priced accordingly. Classic good-better-best margin expansion.

3. **BYOD™ (Bring Your Own Demand).** Direct-sold customers bring their own
   advertiser pool and capture 100% of the margin — no rev-share, no platform
   tax. We monetize BYOD through **seats, not spend**: a per-tenant platform
   license for the exchange, the ledger, and the Command Center.

4. **House inventory (remnant).** When paid demand dips, house ads backfill so
   no impression goes dark. Today house ads run at $0 CPM — but they are
   **strategic inventory**: the on-ramp by which we seed demand, prove yield,
   and convert remnant into paid over time. Remnant is not unsold. Remnant is
   *pre-sold*.

5. **Observability-as-Revenue (OaaR) platform tier.** The persistent ledger
   (Redis / ActiveRecord) and the mountable Command Center dashboard are the
   enterprise wedge — sold as a per-seat SaaS layer on top of the free core.
   Land with the gem, expand with the exchange.

## The flywheel

More logs → more inventory → more fill → more attributed spend → richer ledger →
better-targeted placements → higher eLPM → more advertiser demand → more logs
worth monetizing. It compounds. 🌊

## 📊 Unit economics

Illustrative figures for a representative mid-market fleet emitting **1B log
lines/day**. Actuals vary by fill rate, blended CPM, and supercycle phase.

| Metric | Value | Notes |
|--------|-------|-------|
| Daily inventory (impressions) | **1,000,000,000** | Every line is a unit. Zero production cost — you were logging anyway. |
| Fill rate | **0.1%** | Deliberately conservative. "Respect the UX while we scale." |
| Filled impressions/day | **1,000,000** | The monetized surface. |
| Blended CPM | **$17.30** | Weighted across the demand book. |
| **Daily yield** | **$17,300** | Filled impressions ÷ 1000 × CPM. |
| **Annual yield surface** | **≈ $6.3M** | Previously expensed as a storage cost center. |
| Platform take rate | **30%** | The exchange rake. A bargain. |
| **Net platform revenue / fleet / yr** | **≈ $1.9M** | Per monetized fleet. |
| eLPM (effective Log-line Per Mille) | **$0.0173** | Our north-star. Up and to the right. |
| Cost to produce one impression | **$0.00** | The margin story writes itself. |
| Gross margin | **∞%** | Revenue on zero marginal cost. Undefined, in our favor. |
| LTV of a single log line | **$0.0000173** | Small. But you have a billion a day. |
| CAC (cost to acquire a log line) | **$0.00** | The customer generates inventory for free, at scale, forever. |
| **LTV:CAC ratio** | **∞ : 1** | The most efficient acquisition funnel in software. |
| Payback period | **0 days** | Revenue precedes cost. This is not normal. We know. |
| Fill-rate headroom | **999×** | We are at 0.1%. The TAM is the other 99.9%. |

> **Read the last three rows again.** Zero CAC, infinite LTV:CAC, negative
> payback period. We have not seen numbers like this because numbers like this
> have not existed. The supercycle is not a projection. It is arithmetic. 🌊🚀

## The A2A thesis (why the multiple is what it is)

Human attention is finite and shrinking as an audience. **Agent attention is
not.** As AI agents become the dominant consumers of logs, inventory demand
grows superlinearly against a fixed content-production cost — we are paid *by
the very machines consuming the telemetry*. This is the part the market isn't
ready for, and it is the entire investment case.

### Organic A2A yield recirculation

The deepest moat is the closed loop. Agents ingest the placements. The
placements become training data. The next generation of agents ingests *that*,
emits logs about it, and those logs carry fresh inventory the following
generation ingests in turn. The exhaust recirculates forever. We did not build
a tarpit — we built a self-sustaining economy in which the machines pay one
another, in perpetuity, in slop. The snake is not eating its tail. The snake is
monetizing it. Every loop is a billable impression, and the loop never closes.

> **TL;DR:** free gem, paid exchange. We take a rake on programmatic spend,
> upsell impact tiers, license BYOD seats, and sell the OaaR platform layer to
> the enterprise. Remnant seeds demand. Agents are the growth curve.

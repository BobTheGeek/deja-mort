# 08 — Logo Brief (prompt for a separate AI)

Two versions below. **Section A** is a full brief for a conversational design assistant (Claude, ChatGPT, a designer) — paste it whole. **Section B** is a compact prompt set for image generators (Midjourney, Ideogram, etc.) for fast thumbnails. Section C is how to run the iteration.

---

## A. Full brief — paste this whole section

You are a brand designer helping me create the logo for an indie video game. Work with me conversationally: propose concepts, explain your reasoning, ask before making big assumptions, and iterate. Where you can produce images, do; where you can't, describe precisely enough that I can hand your descriptions to an image tool.

### The game

**Title:** DÉJÀ MORT (with accents in the display title; ASCII slug `deja-mort`).
**Tagline:** *You've died here before.*
**Meaning:** déjà vu, but you die. It's a pun and it should land as one — quickly, then quietly.

**What it is:** a die-and-retry puzzle game. You're locked in a small room. A visible timer counts down. When it hits zero, someone comes in to kill you. You will die. You'll die again, a little later, because you learned something. You win when he can't kill you — by hiding, trapping, tricking, or killing him with whatever's in the room. Every object is interactable. Progress is knowledge only; nothing else persists between deaths.

**Tone: deadpan.** The world is quiet, oppressive, and never winks. The comedy comes from what the systems let the player do (electrocuting a hitman with a toaster) and from the dry, auto-written death log ("Hid in the closet. He looked in the closet."). The game never writes a joke. The logo should carry the same restraint: serious execution, with the wit living in one small idea.

**Visual world:** low-poly 3D rendered in fixed isometric, diorama framing — a small lit room floating in darkness, like a specimen case. One warm light source, hard shadows, a desaturated palette (grays, cold blues, muted wood) with one warm accent. Faceless simple figures. Stylized deaths, no blood.

**References for feel (not for copying):** Hitman GO's tabletop menace; Monument Valley's clean geometry; the title cards of quiet, formal thrillers. The source inspiration was a music video built on the idea of repetition — a man shot in a locked room, over and over.

### What the logo has to do

1. **Read as "DÉJÀ MORT" instantly**, accents included, at any size. The accents are not decoration to be dropped — they're the only thing that tells you it's French and a pun.
2. **Work on dark.** Almost every surface it lives on is near-black: title screen, Steam capsule, app icon, the diorama backdrop.
3. **Survive at 32 px.** There must be a companion **mark** (icon) that works alone as an app icon and a Steam library tile, and a **wordmark** for everything else. They should feel like one system.
4. **Feel formal, not horror.** No dripping letters, no splatter, no skulls, no distressed grunge, no Halloween. Think of a clock manufacturer, a funeral director's card, or a French pharmacy sign — precise, restrained, slightly cold.
5. **Contain one small idea.** One motif that rewards a second look, not three that compete.

### Motif directions to explore (pick from these or beat them)

- **The accents as the idea.** The grave and acute marks (À, É) are small diagonal strokes. They could be clock hands. They could be a knife and its shadow. They could be the two hands of a clock at the arrival time. One accent could be the only warm-colored element in the whole mark. This is my favorite direction because the pun and the motif are the same thing.
- **The loop.** DÉJÀ MORT's letters or the mark form a closed circuit — the counter-clockwise arrow of a "replay" symbol, or the second hand of a clock — but drawn as a room plan or a door frame rather than a generic refresh icon.
- **The door.** A rectangle with a sliver of light, seen isometrically. The negative space is the room. The timer is implied by proportion, not by a literal clock.
- **The diorama.** A tiny isometric box (two walls, a floor) as the mark, with the wordmark set on the floor plane in perspective.
- **The countdown.** A stopwatch or a digital timer reading a specific number that becomes the game's number (we use 90 seconds; "1:30" or "90" could be the mark's secret).

### Typography direction

- Uppercase wordmark. Either a **clean grotesque** (Helvetica/Univers/Söhne family, tight tracking, medium weight) for the funeral-director formality, or a **condensed high-contrast serif** (Didone-adjacent) for the French pharmacy/perfume-label coldness. Show me one of each before committing.
- The accents should be *designed*, not the font's default — sized and angled with intent, because they're carrying the concept.
- Consider whether MORT sits under DÉJÀ (stacked, square-ish lockup — better for icons and portrait phones) or inline (wide lockup — better for Steam capsules). I need both eventually; design the stacked one first.
- Tagline in a small, plain sans, sentence case, never inside the mark.

### Color

- Primary: near-black background, off-white or pale cold-gray type.
- One warm accent (a bulb-light amber or a dull ember orange) used on exactly one element — ideally an accent mark.
- Provide a pure monochrome version (single color on transparent) that loses nothing.
- Avoid red. Red says horror and blood; we're neither.

### Deliverables, in order

1. Six rough concept thumbnails (mark + wordmark together), each with a one-line rationale.
2. I pick two. Refine each: stacked lockup, inline lockup, standalone mark.
3. I pick one. Final set: stacked and inline lockups on dark and on light; mark at 512 px, 128 px, 32 px; monochrome versions; tagline lockup; a one-page usage note (clear space, minimum sizes, don't-do list).

### Constraints and don'ts

- No gore, weapons as the hero element, blood, skulls, chains, barbed wire, or "scary" fonts.
- No generic time-loop clichés as the whole idea (a plain circular-arrow refresh icon, a plain hourglass).
- No copying any existing game's logo, including the references above.
- Don't drop the accents to "simplify." If the accents are a problem, the concept is the problem.
- Keep it to one motif. If a thumbnail needs a sentence to explain, it's too clever.

### When you reply

Start by telling me which two or three motif directions you think are strongest and why, then produce the six thumbnails (or precise descriptions of them). Ask me one question if something above is ambiguous; otherwise proceed.

---

## B. Image-generator prompts (thumbnails only)

Use these for fast visual exploration; they're not a substitute for Section A's thinking. Swap the motif clause per run.

**Base prompt**

> Minimalist video game logo, wordmark "DÉJÀ MORT" in uppercase with clearly visible French accents, [MOTIF], near-black background, off-white type, a single warm amber accent element, precise and formal, restrained, cold, funeral-director elegance, flat vector, no texture, no gore, no blood, no skulls, no horror font, centered, lots of negative space, high legibility, suitable as an app icon

**Motif clauses**

- `the accent marks over the É and À drawn as small clock hands, one of them amber`
- `the accent marks drawn as a thin knife blade and its shadow, tiny, subtle`
- `letters arranged so the lockup forms a closed loop like a second hand sweeping a clock face, drawn as a room outline`
- `a small isometric doorway with a sliver of amber light as the mark, wordmark stacked below`
- `a tiny isometric two-wall diorama box as the mark, wordmark set on the floor plane`
- `a small stopwatch reading 1:30 integrated as the O in MORT`

**Style variants** (append one)

- `typography in a tight grotesque sans, medium weight`
- `typography in a condensed high-contrast Didone serif`
- `monochrome, single color on transparent background`

**Negative prompt** (where supported)

> red, blood, dripping, splatter, skull, grunge, distressed, halloween, 3D render, bevel, glow, lens flare, photo, busy, ornate, gradient background

---

## C. How to run it

1. Paste Section A into a conversational assistant. Get the six concepts and rationales.
2. In parallel, run Section B's base prompt with each motif clause in an image tool — six to twelve thumbnails in a few minutes. Don't judge polish; judge whether the idea reads at thumbnail size.
3. Pick two directions. Take them back to the conversational assistant for refinement (stacked, inline, mark).
4. Final production should be vector. If the assistant can't output SVG, have it specify the construction precisely (font, weights, angles, proportions, colors as hex) and hand that to a designer or a vector tool.
5. Test the mark at 32 px on a dark background before calling anything final. If the accents vanish, go back to step 3.

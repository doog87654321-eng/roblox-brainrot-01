// Brainrot Bay: the entrypoint for make.fun's roblox-brainrot-01 bounty.
// It hands the game in: game.rbxl (the Rojo-built place), src/ (every Luau
// script in it), screenshots/ (three captures of the game) and PLAY.json
// (the published place's link) are copied to the output directory, and
// /output/dossier.json is written with the vendored make.fun library, so the
// judge reads the same summary the gate recomputes.
//
// Runs on Node 22, standard library only, with no install and no network:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
// The grader runs it with /output as the directory instead.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// The grader refuses any output name that starts with a dot (.gitkeep,
// .DS_Store, .git): leave every dotted file and directory out of the copy.
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

mkdirSync(out, { recursive: true });
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
	cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// The caps are the gate's own: only text_max_bytes shapes the bytes, the
// rest make this program fail exactly where the scorer would refuse it
// (more than 4 screenshots, one over 256 KiB, a place past its instance,
// script-source or script-path caps).
writeFileSync(
	join(out, 'dossier.json'),
	buildDossier(out, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

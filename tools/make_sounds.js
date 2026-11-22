#!/usr/bin/env node
// Makes the game's sound effects (slice 4 step 32) into web/sounds/, one WAV per game.Sound after
// None, in the enum's order (src/game/sound.odin). jsfxr (tools/sfx/, public domain, from sfxr.me)
// with Math.random seeded, so running this again makes the same set. Run: node tools/make_sounds.js
"use strict";
const fs = require("fs");
const path = require("path");

let seed = 0;
Math.random = function () { // mulberry32
	seed = (seed + 0x6d2b79f5) | 0;
	let t = seed;
	t = Math.imul(t ^ (t >>> 15), t | 1);
	t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
	return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};

global.window = {};
const lib = require("./sfx/sfxr.js");
const sfxr = lib.sfxr || lib;

const NOISE = 3, SQUARE = 0, SINE = 2;
// name, preset, then changes to its parameters
const SOUNDS = [
	["warning", "tone", { wave_type: NOISE, p_base_freq: 0.12, p_freq_ramp: 0.06, p_env_attack: 0.35, p_env_sustain: 0.25, p_env_decay: 0.3, p_lpf_freq: 0.35, sound_vol: 0.18 }],
	["gust", "tone", { wave_type: NOISE, p_base_freq: 0.2, p_freq_ramp: -0.08, p_env_attack: 0.12, p_env_sustain: 0.3, p_env_decay: 0.45, p_lpf_freq: 0.5, sound_vol: 0.3 }],
	["slam", "explosion", { p_base_freq: 0.08, p_env_sustain: 0.12, p_env_decay: 0.25, sound_vol: 0.3 }],
	["hit", "hitHurt", { sound_vol: 0.25 }],
	["miss", "jump", { wave_type: NOISE, p_base_freq: 0.5, p_freq_ramp: -0.3, p_env_sustain: 0.1, p_env_decay: 0.18, sound_vol: 0.15 }],
	["hurt", "hitHurt", { p_base_freq: 0.18, wave_type: SQUARE, sound_vol: 0.25 }],
	["pick_up", "pickupCoin", { sound_vol: 0.2 }],
	["spell", "laserShoot", { sound_vol: 0.2 }],
	["level", "powerUp", { sound_vol: 0.22 }],
	["key", "click", { p_base_freq: 0.35, p_env_decay: 0.12, sound_vol: 0.3 }],
	["fanfare", "powerUp", { wave_type: SQUARE, p_base_freq: 0.3, p_freq_ramp: 0, p_arp_mod: 0.4, p_arp_speed: 0.55, p_repeat_speed: 0, p_env_sustain: 0.35, p_env_decay: 0.35, p_vib_strength: 0.1, p_vib_speed: 0.5, sound_vol: 0.22 }],
];

const out = path.join(__dirname, "..", "web", "sounds");
fs.mkdirSync(out, { recursive: true });
for (const [i, [name, preset, changes]] of SOUNDS.entries()) {
	seed = 0x5b10_5734 + i * 7919; // each sound its own seed, so changing one leaves the rest
	const p = sfxr.generate(preset, { sample_rate: 22050, sample_size: 8 });
	Object.assign(p, changes);
	const wave = sfxr.toWave(p);
	const bytes = Buffer.from(wave.dataURI.split(",")[1], "base64");
	fs.writeFileSync(path.join(out, name + ".wav"), bytes);
	console.log(name + ".wav", bytes.length);
}

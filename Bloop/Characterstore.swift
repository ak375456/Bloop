//
//  CharacterStore.swift
//  Bloop
//
//  ╔══════════════════════════════════════════════════════════════╗
//  ║  ADD YOUR CHARACTERS HERE — one line per character.         ║
//  ║                                                              ║
//  ║  Steps to add a new character:                              ║
//  ║  1. Drag your 6 WebP frames into Xcode's asset catalog OR   ║
//  ║     into the project's Resources folder (see README).       ║
//  ║  2. Add a Character(...) entry in the `all` array below.    ║
//  ║     • name        → shown on the home-screen card           ║
//  ║     • framePrefix → the shared part before _01/_02/…        ║
//  ╚══════════════════════════════════════════════════════════════╝

import Foundation

enum CharacterStore {
    static let all: [Character] = [

        // ── Example ───────────────────────────────────────────────────
        // Images: santa_clause_walking_01.webp … santa_clause_walking_06.webp
        Character(
            name: "Santa Claus",
            framePrefix: "santa_walking",
            frameCount: 13
        ),
        Character(
            name: "Skeleton",
            framePrefix: "skeleton_walking",
            frameCount: 8
        ),
        Character(
            name: "Banana Man",
            framePrefix: "banana_walking",
            frameCount: 10
        ),
        Character(
            name: "Bird",
            framePrefix: "bird_walking",
            frameCount: 9
        ),
        Character(
            name: "Bleepy",
            framePrefix: "bleepy_walking",
            frameCount: 9
        ),
        Character(
            name: "Zombie",
            framePrefix: "zombie_walking",
            frameCount: 8
        ),
        Character(
            name: "Blu",
            framePrefix: "blu_walking",
            frameCount: 6
        ),
        Character(
            name: "Bronco",
            framePrefix: "bronco_walking",
            frameCount: 6
        ),
        Character(
            name: "Cat",
            framePrefix: "cat_walking",
            frameCount: 6
        ),
        Character(
            name: "Dragon",
            framePrefix: "dragon_walking",
            frameCount: 6
        ),
        Character(
            name: "Easter Bunny",
            framePrefix: "easter_bunny_walking",
            frameCount: 6
        ),
        Character(
            name: "Flare",
            framePrefix: "flare_walking",
            frameCount: 6
        ),
        Character(
            name: "Gangstar",
            framePrefix: "gangsters_walking",
            frameCount: 10
        ),
        Character(
            name: "Girl",
            framePrefix: "girl_walking",
            frameCount: 6
        ),
        Character(
            name: "Jet",
            framePrefix: "jet_walking",
            frameCount: 6
        ),
        Character(
            name: "Labubu",
            framePrefix: "labubu_walking",
            frameCount: 6
        ),
        Character(
            name: "Sunny",
            framePrefix: "sunny_walking",
            frameCount: 6
        ),
        Character(
            name: "Mustang",
            framePrefix: "mustang_walking",
            frameCount: 11
        ),
        Character(
            name: "Pengiun",
            framePrefix: "penguin_walking",
            frameCount: 11
        ),
        Character(
            name: "UFO",
            framePrefix: "ufo_walking",
            frameCount: 8
        ),
        Character(
            name: "Fox",
            framePrefix: "wolf_walking",
            frameCount: 9
        ),
        Character(
            name: "The Boy",
            framePrefix: "the_boy_walking",
            frameCount: 15
        ),
        Character(
            name: "Xippy",
            framePrefix: "zippy_walking",
            frameCount: 12
        ),

        // ── Add more characters below ─────────────────────────────────
        // Character(
        //     name: "Elf",
        //     framePrefix: "elf_walking"
        // ),
        // Character(
        //     name: "Penguin",
        //     framePrefix: "penguin_walking",
        //     walkSpeed: 1.0,      // slower
        //     ticksPerFrame: 7     // more frames between animation steps
        // ),
    ]
}

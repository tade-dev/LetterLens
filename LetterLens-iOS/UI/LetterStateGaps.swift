//
//  LetterStateGaps.swift
//  LetterLens-iOS
//
//  States 12–18 were looked up in docs, design notes, CLAUDE.md, the README,
//  design/, docs/, code comments, TODOs, and the existing screens.
//  Nothing in the repo specifies a layout for 12, 13, 14, 16, or 18.
//  State 15's purpose is the reading failure already named by ReadingScreen.
//  State 17 is the keep-private sheet from the welcome/privacy work.
//
//  TODO: State 12. No empty-state strings in the repo. Home keeps the existing ContentUnavailableView ("No letters yet" / "Scan a letter and it will show up here."). Needs Prism's spec.
//  TODO: State 13. No spec in the repo, and the code does not say what this state is. Needs Prism's spec.
//  TODO: State 14. No spec in the repo, and the code does not say what this state is. Needs Prism's spec.
//  TODO: State 16. No spec in the repo, and the code does not say what this state is. Needs Prism's spec.
//  TODO: State 17. The keep-private sheet is already on screen. No replacement for its placeholder copy was in the repo. Needs Prism's spec.
//  TODO: State 18. No spec in the repo, and the code does not say what this state is. Needs Prism's spec.

enum LetterStateGaps {}

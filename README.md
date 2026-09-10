# Endless Runner (CS-5105N Game Development)

A 2D game project built in Godot 4, developed as part of the CS-5105N Game Development course. This repository documents the Week 1 setup activity: environment installation, initial scene creation, and version control configuration.

## Game Concept

**Working Title:** Endless Runner
**Genre:** Arcade / Survival

A 2D dodge-and-survive game where the player controls a character avoiding falling hazards. Difficulty scales over time as obstacles increase in speed and frequency, testing player reflexes.

## Tech Stack

- **Engine:** Godot 4.7.2 (Standard build, GDScript)
- **Version Control:** Git + Git LFS
- **Platform:** macOS (Apple Silicon)

---

## Week 1 Activity: Godot & Git Setup

### Objective
Install the development environment, create a minimal working 2D scene, and establish version control for the project.

### 1. Godot Installation & Project Setup
Godot 4.7.2 (Standard build) was installed and a new project, `endlessrunner`, was created.

*[Screenshot: Godot's Create Root Node screen]*

### 2. Scene Construction
A `Node2D` was added as the scene root, with a `Sprite2D` child node assigned a placeholder texture (`icon.svg`).

*[Screenshot: Scene tree showing Node2D > Sprite2D with texture loaded in Inspector]*

The scene was saved as `main.tscn` and set as the project's main scene.

### 3. Running the Scene
The scene was run successfully via the editor's Play button, confirming the sprite renders correctly in a standalone game window with no runtime errors.

*[Screenshot: endlessrunner (DEBUG) window showing the running scene, Output log clean]*

### 4. Version Control Setup
A private GitHub repository was created, and the local project was initialized with Git:

```bash
git init
git branch -m main
```

A `.gitignore` was added to exclude Godot's auto-generated cache and platform-specific files:

```
.godot/
export_presets.cfg
/android/
```

*[Screenshot: Terminal showing .gitignore creation and `ls -a` confirming it was tracked]*

### 5. Git LFS Configuration
Git LFS was installed and configured to track large binary art assets, preventing repository bloat:

```bash
git lfs install
git lfs track "*.png"
git lfs track "*.wav"
```

*[Screenshot: Terminal output of `cat .gitattributes` showing LFS filter rules]*

### 6. Authentication & Push
GitHub CLI (`gh`) was used to authenticate Git operations under the correct account, resolving an initial permission mismatch between two local GitHub credentials.

```bash
git add .
git commit -m "Week 1: project setup + Hello World"
git push -u origin main
```

*[Screenshot: Terminal confirming successful push — `main -> main`, branch tracking `origin/main`]*

### Result
- ✅ Godot project runs a working 2D "Hello World" scene
- ✅ Repository initialized, committed, and pushed to GitHub
- ✅ `.gitignore` and Git LFS correctly configured
- ✅ README documents the setup process with evidence

---

## Repository Structure

```
endlessrunner/
├── .gitignore
├── .gitattributes
├── icon.svg
├── main.tscn
├── project.godot
└── README.md
```

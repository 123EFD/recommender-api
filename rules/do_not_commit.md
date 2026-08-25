---
name: do_not_commit
description: Do Not Commit learning rule. Algorithms should be left blank in the code and explained here for learning purposes.
---

# Do Not Commit & Learning Algorithms Guide

**Rule:** When the user is learning a new theoretical algorithm or advanced backend logic, the AI Agent MUST NOT write the core logic directly into the source code (e.g., `main.py`). The logic block must be left blank with `pass` and a `TODO` comment so the user can implement it themselves.

**Prerequisite Knowledge & Research:**
All theoretical explanations for advanced features must be documented here in this file for the user to study.

---

## 1. "Root-Cause" Prerequisite Back-Tracing Engine
**Concept:** A student struggling in a specific advanced subject often lacks fundamental prerequisite knowledge.
**Algorithm (DAG Traversal):**
- We model the curriculum as a Directed Acyclic Graph (DAG) where nodes are subjects, and edges represent prerequisites.
- Example: `WIA1006 (Machine Learning)` ➔ requires `WIA2003 (Probability & Statistics)` and `WIF3009 (Python)`.
- When tracing back, we use **Depth-First Search (DFS)** to traverse upstream recursively.
- For each visited node, we query the `learning_resources` database to fetch targeted micro-resources.
- **Topological Sorting** ensures we present the foundational prerequisites *before* the intermediate ones in the UI.

## 2. Peer-Validated "High-Yield" Heatmap
**Concept:** Not all study resources are equal. We want to find resources that specifically help *at-risk* or *struggling* students improve, ignoring votes from students who already had straight A's.
**Algorithm (Wilson Score Interval):**
- Simply calculating average rating (e.g., 5/5 stars) is flawed because 1 positive review (100%) ranks higher than 98 positive reviews out of 100 (98%).
- **Wilson Score Confidence Interval** balances the proportion of positive ratings against the total number of ratings to establish a statistically reliable lower-bound estimate.
- **Formula:** 
  `P_hat = (positive_successes) / (total_attempts)`
  The formula calculates the lower bound of a normal approximation interval.
- **Filtering (Targeted Cohort):** The algorithm filters the dataset to ONLY include ratings submitted by students whose initial grade was poor (e.g., < 40%) but showed an improvement delta after viewing the resource.
- **Heat Computation:** The resulting Wilson Score is mapped to a color temperature gradient (e.g., 0.90+ = Deep Red/Orange 🔥, 0.75+ = Yellow ⭐) for rendering in the Heatmap UI.

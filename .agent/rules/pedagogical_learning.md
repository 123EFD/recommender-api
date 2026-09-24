---
name: pedagogical_learning_and_concepts
description: Rules for leaving core logic blank for learning and documenting interview & real-world applications of applied concepts.
---

# Pedagogical Learning & Applied Concepts Rule

## Mandatory Agent Workflow

1. **Leave Core Logic Blank for Active Learning**:
   - When implementing core algorithmic procedures or advanced business logic, the agent MUST NOT provide the complete solution in the codebase.
   - Use `[BLANK N]` with descriptive type annotations, input parameters, expected return structures, and a `pass` or safe fallback return.
   
2. **Document Applied Concepts with Interview & Production Context**:
   - For every blank logic block and advanced concept, the agent MUST provide:
     1. **Mathematical & Algorithmic Foundation**: Deep theoretical mechanics, formulas, time/space complexity ($O(N)$), and trade-offs.
     2. **Production / Real-World Applications**: Where this exact algorithm or design pattern is used in industry (e.g., Google, Netflix, Uber, AWS, LLM RAG pipelines).
     3. **Technical Interview Applications**: How to present this concept in technical interviews, common interviewer questions, edge cases, and design discussions.

---

## Pinned Master Roadmap & Priority Registry

| # | Improvement | Origin Date | Complexity | Priority | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Micro-Diagnostic 2-Min Adaptive Quiz (CAT) | 2026-07-31 | High | 🔥 High | Pending |
| 2 | Bayesian / Deep Knowledge Tracing (BKT/DKT) | 2026-07-31 | High | Medium | Pending |
| 3 | Multimodal PYQ Photo Scanner & Timestamp Mapper | 2026-07-31 | High | Medium | Pending |
| 4 | Native Interactive Mermaid Flowchart Render | 2026-08-08 | Medium | 🔥 High | Pending |
| 5 | Lens Transformation Cache Layer | 2026-07-31 | Low | Low | Pending |
| 6 | Flashcard Deep-Dive Explanations & Links | 2026-08-17 | Low – Medium | Medium | **ACTIVE** |
| 7 | Real student_quiz_logs Table & In-App Voting | 2026-08-21 | Medium | 🔥 High | Pending |
| 8 | Live YouTube API Search for Video Resources | 2026-08-25 | Medium | Medium | **ACTIVE** |
| 9 | PDF.js Web Worker & Semantic Chunk Retrieval Fix | 2026-09-14 | Low – Medium | Medium | Pending |

---

## Pinned Architectural Blueprint: Flashcard Topic Relevance, External Question Datasets & Heatmap Integration

### 1. Root Cause of Topic Contamination
- **Legacy Database Noise**: Historic records in `resources.db` contained mismatched topic labels (e.g., OOP record `#10212` labeled as "Computer Networks").
- **Unconstrained Fallback**: When candidates fell short for a time budget, `app/bundler.py` previously executed an unrestricted `ORDER BY RANDOM()` on `General CS`, leaking dynamic programming and recursion into unrelated networking decks.

### 2. The 4-Pillar Architectural Solution
1. **Dual-Tier Generation Model**:
   - Primary: Curated, high-yield university past-exam question banks (PYQs).
   - Dynamic: On-demand PDF RAG generation using authoritative uploaded textbooks (`Topic01-Foundation.pdf`, `Algorithms-JeffE.pdf`, `DiscMathII.pdf`).
2. **Prerequisite-Aware Fallback (DAG Traversal)**:
   - If candidate resources for a specific topic run short, the bundler NEVER falls back to random `General CS`.
   - Instead, it traverses `COURSE_PREREQUISITES` to only source foundational prerequisite cards (e.g. `WIA1005 (Computer Networks)` falls back to its immediate ancestor `WIA1003 (Computer Systems Architecture)`).
3. **Semantic Relevance Embedding Guard**:
   - Computes cosine similarity between candidate flashcard embeddings and canonical syllabus topics:
     $$\text{CosineSim}(\vec{E}_{\text{card}}, \vec{E}_{\text{course}}) = \frac{\vec{E}_{\text{card}} \cdot \vec{E}_{\text{course}}}{\|\vec{E}_{\text{card}}\| \|\vec{E}_{\text{course}}\|}$$
   - Any candidate scoring $< 0.65$ is automatically purged from the study bundle.
4. **Adaptive Wilson Score Heatmap Integration**:
   - Integrates `student_quiz_logs` to adaptively boost high-heat flashcards (proven to help struggling students master threshold concepts).
   - Extensible to any newly registered course in `kAvailableCourses`.


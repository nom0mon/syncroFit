# Resistance-training prescription research source

Audience: SynchroFit product/development team  
Date: 2026-09-05  
Scope: Healthy adults performing general resistance training; excludes rehabilitation, acute injury, pregnancy-specific programming, and competitive peaking.

## Executive answer

There is no evidence-based universal rep/set/rest table determined solely by experience level. Fitness level should determine conservative starting volume and progression. Training goal and exercise type should determine repetition and rest targets. Advanced users do not inherently need shorter rest; preserving performance with sufficient rest, controlling weekly per-muscle volume, avoiding routine failure training, and removing biomechanically redundant exercises are better fatigue controls.

## Evidence synthesis

- The 2026 ACSM position stand synthesized 137 systematic reviews (>30,000 participants). Strength was enhanced by heavier loads (at least 80% 1RM), 2-3 sets, and at least two weekly sessions; hypertrophy was enhanced by at least 10 weekly sets per muscle. Training to momentary failure and complex periodization did not consistently improve outcomes.
- A 2023 network meta-analysis of 178 strength studies and 119 hypertrophy studies found all tested prescriptions improved outcomes. Higher loads ranked best for strength, while multiple sets were important for hypertrophy.
- A 2024 rest-interval meta-analysis found a small hypertrophy advantage above 60 seconds and no appreciable additional hypertrophy difference beyond roughly 90 seconds, though longer rest can preserve volume load. The IUSCA position stand advises at least 2 minutes for multi-joint work and 60-90 seconds for single-joint or some machine work.
- Failure training does not reliably outperform non-failure training for hypertrophy. A controlled study in trained adults found substantially greater acute neuromuscular fatigue and worse perceptual responses at failure than at 1 or 3 repetitions in reserve.
- Volume has diminishing returns. In trained young men, 12-20 weekly sets per muscle was a reasonable hypertrophy range and more than 20 did not consistently improve all muscles. The IUSCA recommends limiting a muscle to about 10 sets in one session and distributing additional weekly work.
- Exercise variation should be systematic and anatomically meaningful. A systematic review found that excessive/random variation and exercises providing redundant stimuli may hinder adaptation.

## Recommended SynchroFit policy

Use working sets only; warm-up sets are not counted. Count a direct set as 1.0 toward a muscle and a compound's secondary-muscle set as 0.5.

| Level | Default sets per exercise | Starting weekly sets per muscle | Effort target | Progression rule |
|---|---:|---:|---:|---|
| Beginner | 2 | 4-8 | 3-4 RIR | Add reps first; add a set only after technique and recovery are stable |
| Intermediate | 3 | 8-12 | 2-3 RIR | Add volume only after a plateau with good recovery |
| Advanced | 3; optionally 4 on one priority lift | 10-16 | 1-3 RIR | Raise one priority muscle at a time; 12-20 only when recovery supports it |

RIR means estimated repetitions remaining before momentary failure.

| Goal/exercise | Repetitions | Rest after every working set |
|---|---:|---:|
| Strength, primary compound | 3-6 | 180 s beginner/intermediate; 180-300 s advanced |
| Hypertrophy, compound | 6-12 | 120-180 s |
| Hypertrophy, isolation/machine | 10-20 | 60-120 s |
| Muscular endurance | 12-20 | 60-90 s; extend if target reps cannot be maintained |
| Timed bodyweight/isometric | 20-45 s | 60-120 s, based on effort and movement complexity |

Implementation defaults when the app cannot infer equipment or exercise type: use 8-12 reps and 120 seconds of rest. Do not decrease rest solely because a user is advanced.

## Redundancy and fatigue rules

1. Assign each exercise a primary movement-pattern tag, primary muscles, secondary muscles, equipment, and joint/angle or region tag.
2. In one session, allow at most two exercises with the same primary muscle and movement pattern. Permit the second only if its angle/region or resistance profile differs.
3. Prefer 4-6 resistance exercises per session. Do not exceed 10 direct sets for one muscle in a session.
4. Keep the same core movements for a 4-8 week block. Replace an exercise for pain, equipment, preference, stagnation, or a deliberate angle/region change—not for random novelty.
5. Do not prescribe routine failure on compound lifts. Beginners remain at 3-4 RIR; intermediate and advanced users generally remain at 1-3 RIR. If failure is offered, limit it to the final set of a low-risk isolation/machine exercise.
6. Add recovery feedback. If target reps fall by more than 20% across sets, performance regresses for two sessions, or soreness/joint discomfort persists, hold or reduce sets before changing exercises.
7. Increase volume gradually and for one priority muscle group at a time. Avoid automatically giving advanced users more exercises simply because of their level.

## Limitations

Rep count is an imperfect proxy for load, and the evidence does not establish precise experience-level cutoffs. Recovery varies with age, sleep, diet, concurrent sport, exercise selection, and health. The app should present these values as starting prescriptions, collect performance/recovery signals, and adapt within bounded server-side rules. Users with medical conditions, injury, or unusual symptoms need individualized professional advice.

## Claim-to-source ledger

1. Currier BS et al. *American College of Sports Medicine Position Stand. Resistance Training Prescription for Muscle Function, Hypertrophy, and Physical Performance in Healthy Adults: An Overview of Reviews.* Medicine & Science in Sports & Exercise, 2026. https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/
2. Lopez P et al. *Resistance training prescription for muscle strength and hypertrophy in healthy adults: a systematic review and Bayesian network meta-analysis.* British Journal of Sports Medicine, 2023. https://pubmed.ncbi.nlm.nih.gov/37414459/
3. Singer A et al. *Give it a rest: a systematic review with Bayesian meta-analysis on the effect of inter-set rest interval duration on muscle hypertrophy.* Frontiers in Sports and Active Living, 2024. https://pubmed.ncbi.nlm.nih.gov/39205815/
4. Schoenfeld BJ et al. *Resistance Training Recommendations to Maximize Muscle Hypertrophy in an Athletic Population: Position Stand of the IUSCA.* International Journal of Strength and Conditioning, 2021. https://journal.iusca.org/index.php/Journal/article/download/81/140/
5. Refalo MC et al. *Influence of Resistance Training Proximity-to-Failure on Skeletal Muscle Hypertrophy: A Systematic Review with Meta-analysis.* Sports Medicine, 2023. https://pubmed.ncbi.nlm.nih.gov/36334240/
6. Pareja-Blanco F et al. *Influence of Resistance Training Proximity-to-Failure, Determined by Repetitions-in-Reserve, on Neuromuscular Fatigue in Resistance-Trained Males and Females.* Sports Medicine - Open, 2023. https://pubmed.ncbi.nlm.nih.gov/36752989/
7. Baz-Valle E et al. *A Systematic Review of The Effects of Different Resistance Training Volumes on Muscle Hypertrophy.* 2022. https://pubmed.ncbi.nlm.nih.gov/35291645/
8. Kassiano W et al. *Does Varying Resistance Exercises Promote Superior Muscle Hypertrophy and Strength Gains? A Systematic Review.* Journal of Strength and Conditioning Research, 2022. https://pubmed.ncbi.nlm.nih.gov/35438660/

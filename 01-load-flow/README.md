# Project 1: 5-Bus Load Flow Study

Newton-Raphson AC load flow on a 5-bus, 161 kV test system, solved three independent ways and compared:

1. **MATLAB:** own Newton-Raphson solver written from scratch (`matlab/`)
2. **Python:** pandapower (`python/`)
3. **ETAP:** cross-check using ETAP's load flow module (`etap/`)

> **Note:** This is a generic test system with illustrative parameters, not measured data from any real grid. It is meant to practise the method on a transmission-style network. A planned extension is to rebuild it from publicly available Ghana transmission data.

## System data (100 MVA base, 161 kV, 50 Hz)

| Bus | Type | Data |
|---|---|---|
| 1 | Slack | V = 1.05 pu, angle 0 |
| 2 | PV | P = 80 MW, V = 1.03 pu |
| 3 | PQ | Load 60 MW, 25 Mvar |
| 4 | PQ | Load 50 MW, 20 Mvar |
| 5 | PQ | Load 40 MW, 15 Mvar |

| Line | R (pu) | X (pu) | B total (pu) |
|---|---|---|---|
| 1-2 | 0.02 | 0.06 | 0.06 |
| 1-3 | 0.08 | 0.24 | 0.05 |
| 2-3 | 0.06 | 0.18 | 0.04 |
| 2-4 | 0.06 | 0.18 | 0.04 |
| 3-4 | 0.01 | 0.03 | 0.02 |
| 4-5 | 0.08 | 0.24 | 0.05 |

Assumed acceptable voltage band: **0.95 to 1.05 pu**.

## Scenarios

| ID | Description |
|---|---|
| A | Base case |
| B | Peak load (all loads +20%) |
| C | Outage of line 2-4 |
| D | Base case + 30 Mvar shunt capacitor at Bus 5 |

## Base case results (MATLAB Newton-Raphson)

Converged in 4 iterations (mismatch tolerance 1e-8 pu).

| Bus | V (pu) | Angle (deg) |
|---|---|---|
| 1 | 1.0500 | 0.000 |
| 2 | 1.0300 | -0.722 |
| 3 | 0.9631 | -5.377 |
| 4 | 0.9547 | -5.953 |
| 5 | 0.8775 | -11.814 |

Slack generation: 78.49 MW / 42.78 Mvar. Generator 2 Q output: 17.16 Mvar. Total losses: 8.49 MW.

## Scenario comparison

| Scenario | Slack MW | Losses MW | Vmin (pu) | Bus |
|---|---|---|---|---|
| A: Base | 78.49 | 8.49 | 0.8775 | 5 |
| B: Peak +20% | 113.48 | 13.48 | 0.8290 | 5 |
| C: Line 2-4 out | 85.54 | 15.54 | 0.7846 | 5 |
| D: Base + 30 Mvar cap | 77.34 | 7.34 | 0.9800 | 4 |

## Tool comparison

| Quantity | MATLAB | pandapower | ETAP |
|---|---|---|---|
| Bus 5 voltage (pu) | 0.8775 | [fill in] | [fill in] |
| Bus 5 angle (deg) | -11.814 | [fill in] | [fill in] |
| Slack MW | 78.49 | [fill in] | [fill in] |
| Total losses (MW) | 8.49 | [fill in] | [fill in] |

## Key findings

- In the base case, **Bus 5 sits at 0.8775 pu**, well below the 0.95 pu limit, and Bus 4 is marginal at 0.9547 pu. The weak point is the radial branch 4-5, which feeds Bus 5 through a single line.
- **Peak load** (+20%) pushes Bus 5 to 0.829 pu and Bus 3 and Bus 4 below 0.95 pu as well.
- **Losing line 2-4** is the most severe contingency: all three load buses fall below 0.95 pu (Bus 5 at 0.785 pu) and losses rise to 15.54 MW.
- A **30 Mvar capacitor at Bus 5** lifts every bus to 0.98 pu or higher in the base case and cuts losses from 8.49 MW to 7.34 MW. Reactive support placed at the weak bus fixes the problem close to where it starts.

## Repository layout

```
01-load-flow/
  matlab/loadflow_nr.m        Newton-Raphson solver (function)
  matlab/run_project1.m       Runs all scenarios, prints tables, saves figure and CSV
  python/loadflow_pandapower.py
  etap/                       ETAP screenshots and one-line diagram
  results/                    Figures and CSV summaries
```

## How to run

**MATLAB** (R2019a or later): open `matlab/run_project1.m` and press Run.

**Python:**
```
pip install pandapower matplotlib pandas
python python/loadflow_pandapower.py
```

## ETAP cross-check: entering the data

Base impedance Zbase = 161^2 / 100 = 259.21 ohm.

| Line | R (ohm) | X (ohm) | Total line charging Y (uS) |
|---|---|---|---|
| 1-2 | 5.184 | 15.553 | 231.5 |
| 1-3 | 20.737 | 62.210 | 192.9 |
| 2-3 | 15.553 | 46.658 | 154.3 |
| 2-4 | 15.553 | 46.658 | 154.3 |
| 3-4 | 2.592 | 7.776 | 77.2 |
| 4-5 | 20.737 | 62.210 | 192.9 |

1. Add 5 buses at 161 kV nominal.
2. Bus 1: Power Grid (swing) with 105% voltage. Bus 2: Synchronous Generator in Voltage Control mode, 80 MW, 103% voltage.
3. Buses 3, 4, 5: Lumped loads at 60 MW + 25 Mvar, 50 MW + 20 Mvar, 40 MW + 15 Mvar.
4. Connect lines using the impedance values above (enter length as 1 km if per-length units are required).
5. Load Flow Study Case: Newton-Raphson, precision 0.000001. Run it and screenshot the results into `etap/`.

## Next steps

- Rebuild the network from public Ghana transmission data.
- Add transformer tap and generator Q-limit modelling.
- Extend to N-1 contingency screening across all lines.

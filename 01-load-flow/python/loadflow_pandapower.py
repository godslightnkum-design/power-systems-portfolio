"""
Project 1 - 5-Bus Load Flow Study (pandapower)

Same network and scenarios as the MATLAB Newton-Raphson code, so the
two sets of results can be compared directly.

Install:  pip install pandapower matplotlib pandas
Run:      python loadflow_pandapower.py
"""
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import pandapower as pp

BASE_MVA = 100.0
VN_KV = 161.0
F_HZ = 50.0                      # Ghana grid frequency
Z_BASE = VN_KV**2 / BASE_MVA     # 259.21 ohm

# (from, to, R_pu, X_pu, B_total_pu) on 100 MVA base
LINES = [
    (1, 2, 0.02, 0.06, 0.06),
    (1, 3, 0.08, 0.24, 0.05),
    (2, 3, 0.06, 0.18, 0.04),
    (2, 4, 0.06, 0.18, 0.04),
    (3, 4, 0.01, 0.03, 0.02),
    (4, 5, 0.08, 0.24, 0.05),
]
LOADS = {3: (60, 25), 4: (50, 20), 5: (40, 15)}   # bus: (MW, Mvar)


def build_net(load_scale=1.0, drop_line=None, cap_mvar_bus5=0.0):
    net = pp.create_empty_network(sn_mva=BASE_MVA, f_hz=F_HZ)
    bus = {i: pp.create_bus(net, vn_kv=VN_KV, name=f"Bus {i}") for i in range(1, 6)}

    pp.create_ext_grid(net, bus=bus[1], vm_pu=1.05, va_degree=0.0, name="Slack")
    pp.create_gen(net, bus=bus[2], p_mw=80.0, vm_pu=1.03, name="G2")

    for b, (p, q) in LOADS.items():
        pp.create_load(net, bus=bus[b], p_mw=p * load_scale, q_mvar=q * load_scale, name=f"Load {b}")

    for f, t, r_pu, x_pu, b_pu in LINES:
        if drop_line == (f, t):
            continue
        r_ohm = r_pu * Z_BASE
        x_ohm = x_pu * Z_BASE
        b_siemens = b_pu / Z_BASE                       # total line charging
        c_nf = b_siemens / (2 * np.pi * F_HZ) * 1e9
        pp.create_line_from_parameters(
            net, from_bus=bus[f], to_bus=bus[t], length_km=1.0,
            r_ohm_per_km=r_ohm, x_ohm_per_km=x_ohm, c_nf_per_km=c_nf,
            max_i_ka=1.0, name=f"Line {f}-{t}",
        )

    if cap_mvar_bus5 > 0:
        # In pandapower a capacitor is a shunt with NEGATIVE q_mvar
        pp.create_shunt(net, bus=bus[5], q_mvar=-cap_mvar_bus5, p_mw=0.0, name="Cap Bus 5")
    return net


SCENARIOS = {
    "A: Base case": dict(),
    "B: Peak load (+20%)": dict(load_scale=1.2),
    "C: Line 2-4 outage": dict(drop_line=(2, 4)),
    "D: Base + 30 Mvar cap at Bus 5": dict(cap_mvar_bus5=30.0),
}


def main():
    outdir = Path(__file__).resolve().parent.parent / "results"
    outdir.mkdir(exist_ok=True)

    volt = {}
    rows = []
    base_net = None
    for name, kwargs in SCENARIOS.items():
        net = build_net(**kwargs)
        pp.runpp(net, algorithm="nr", tolerance_mva=1e-8, max_iteration=30, init="flat")
        v = net.res_bus["vm_pu"].to_numpy()
        volt[name] = v
        rows.append({
            "Scenario": name,
            "SlackMW": round(float(net.res_ext_grid["p_mw"].iloc[0]), 2),
            "LossMW": round(float(net.res_line["pl_mw"].sum()), 2),
            "Vmin_pu": round(float(v.min()), 4),
            "VminBus": int(v.argmin()) + 1,
        })
        if name.startswith("A"):
            base_net = net

    summary = pd.DataFrame(rows)
    print("\n=== Bus voltages (pu) ===")
    print(pd.DataFrame(volt, index=[f"Bus{i}" for i in range(1, 6)]).T.round(4))
    print("\n=== System summary ===")
    print(summary.to_string(index=False))

    print("\n=== Base case: bus angles (deg) ===")
    print(base_net.res_bus["va_degree"].round(4).to_string())
    print("\n=== Base case: line flows ===")
    print(base_net.res_line[["p_from_mw", "q_from_mvar", "p_to_mw", "q_to_mvar", "pl_mw"]].round(3))

    summary.to_csv(outdir / "pandapower_summary.csv", index=False)

    # Voltage profile figure
    fig, ax = plt.subplots(figsize=(9, 5))
    width = 0.2
    x = np.arange(1, 6)
    for k, (name, v) in enumerate(volt.items()):
        ax.bar(x + (k - 1.5) * width, v, width, label=name)
    ax.axhline(0.95, color="r", ls="--", lw=1.2)
    ax.axhline(1.05, color="r", ls="--", lw=1.2)
    ax.set_ylim(0.7, 1.1)
    ax.set_xlabel("Bus number")
    ax.set_ylabel("Voltage magnitude (pu)")
    ax.set_title("5-Bus System: Voltage Profile by Scenario (pandapower)")
    ax.legend(loc="lower left")
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(outdir / "pandapower_voltage_profile.png", dpi=200)
    print(f"\nSaved results to {outdir}")


if __name__ == "__main__":
    main()

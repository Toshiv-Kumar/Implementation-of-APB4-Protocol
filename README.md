# APB4-Master-Requester-Interface

**APB4 Master/Requester Design in Verilog HDL**
A Verilog-based implementation of an **APB4 Master (Requester)** that translates transfer requests from a bridge into standard AMBA APB protocol signals, focusing on **FSM-based transfer sequencing, byte-strobe writes, protection-attribute checking, and slave error propagation**, verified using a behavioral testbench and simulation waveforms.

![APB4](https://img.shields.io/badge/Protocol-APB4-blue?style=flat-square) <img src="https://img.shields.io/badge/HDL-Verilog-blue.svg" /> <img src="https://img.shields.io/badge/Domain-Bus%20Protocol%20Design-orange.svg" /> <img src="https://img.shields.io/badge/EDA-Generic%20Simulator-brightgreen.svg" />

---

## 🧩 Overview

This project presents the **design and verification of an APB4 Master/Requester interface** (`apb_master_requester`) that translates transfer requests from a bridge (e.g., an AHB-to-APB bridge) into standard AMBA APB protocol signals — `PSELx`, `PENABLE`, `PADDR`, `PWRITE`, `PWDATA`, `PSTRB`, and `PPROT` — driving a peripheral slave, and returns read data and error status back to the bridge/CPU.

The design implements the classic three-phase APB transfer FSM — **IDLE → SETUP → ACCESS** — as a hybrid Mealy/Moore machine, with support for back-to-back transfers, byte-level write strobing (`PSTRB`), protection-attribute checking (`PPROT`), and slave error (`PSLVERR`) propagation to a CPU-facing `error` signal.

Verification uses a self-contained testbench (`tb_apb`) that behaviorally models a peripheral slave — including a byte-addressable memory array, randomized `PREADY` wait-state insertion, and randomized `PSLVERR` injection — while a synchronous `always` block drives bridge-side stimulus using `$urandom()`.

---

## ✨ Features

* APB master/requester FSM: `IDLE → SETUP → ACCESS` (hybrid Mealy/Moore, states encoded `00 → 01 → 11` to minimize toggling/activity factor)
* Back-to-back transfer support (re-entry into `SETUP` directly from `ACCESS`, without returning to `IDLE`)
* Byte-level write strobing via `PSTRB` for partial-word writes
* `PPROT`-based protection checking — a non-secure access flags an error on read
* `PSLVERR` propagation to a CPU-facing `error` output
* Behavioral slave model in the testbench, with a 1024 × 32-bit addressable memory array
* Randomized `PREADY` wait-state insertion and `PSLVERR` injection for stress-testing the handshake
* Delta-cycle-safe testbench design using `forever`/`wait()` instead of level-sensitive `always @(signal)` blocks

---

## 📊 Simulation Waveforms & Schematic

### APB4 Transfer Waveform
*(Insert your simulation waveform screenshot here)*

### Synthesis Schematic
*(Insert your synthesis schematic screenshot here)*

---

## 🛠️ EDA Tools & Technologies

* **HDL:** Verilog
* **Design Style:** FSM-based RTL (hybrid Mealy/Moore)
* **Verification:** Self-contained behavioral testbench (`tb_apb`) with randomized stimulus (`$urandom()`)
* **Protocol:** AMBA APB4 (Advanced Peripheral Bus) — 3-phase IDLE/SETUP/ACCESS transfer

---

## 📘 Learnings / Challenges

> *Learnings/Challenges: (Put some of these in the synth checklist) — check reset in all blocks: 1 or 0*

1. I was unable to understand how the design was using the `PSELx` and `PADDR` signals. I originally thought that `PSELx` simply indicated that one of the slaves was selected, and that `PADDR` specified the specific register — due to a lack of clarity in the source I referred to while implementing this design. Later, I realized that they use **one-hot encoding** for `PSELx`: each slave has its own `PSELx` line, and only one slave's `PSELx` is high (`1`) at a time, with the rest low (`0`). `PADDR` is used to select a specific register within the chosen slave. `PADDR` is useless if it is a read operation.

2. Learned that a testbench can completely simulate connected hardware itself for simulation purposes. Here, it can behave exactly like a slave connected to a master. So, instead of using one-time `initial` blocks, we can use synchronous, clocked `always` blocks in the testbench and connect its ports to our design, just as we normally would.

3. `always @(PREADY)` (level-sensitive): This block fires whenever `PREADY` changes. Inside it, `PSLVERR` and `PRDATA` are assigned (with `#1` delays). Changing `PSLVERR`/`PRDATA` can affect DUT outputs (or testbench logic), which may in turn change `PREADY` within the same simulation time slice or the next delta cycle — this can produce an infinite sequence of delta events and prevent time from advancing.

   At time 0, the simulator runs a number of things before advancing real time: `initial` blocks, continuous assignments, and any `always` blocks sensitive to signals. These create a sequence of zero-time updates called **delta cycles**. Delta cycles let the simulator settle combinational logic and event-driven updates without moving the simulation clock forward.

   `always @(PREADY)` is level-sensitive: it runs whenever `PREADY` changes. Inside it, `PSLVERR` and `PRDATA` change. Those signals can, in turn, affect the DUT or other testbench logic that drives `PREADY`. If that feedback path doesn't require a real clock edge (for example, if it goes through combinational logic or other `always @(...)` blocks), the simulator will keep re-evaluating the chain within the same simulation time, using more delta cycles.

   If the chain never reaches a stable point (each update triggers another update immediately), the simulator keeps executing delta cycles forever at time 0 and never advances to the next real time — so it appears **"stuck at 0fs."**

4. Learned that we can simulate a combinational always block's repeating logic in the testbench using a nested `forever` loop inside an `initial` block, with the help of the `wait()` statement:



---

## 📚 References

*(Add your references here — e.g., ARM AMBA APB Protocol Specification, tutorials, videos, etc.)*

---

## 📖 Theory Overview / Challenges

*(Write your own conceptual/theory section here, similar to the "Theory Overview" section in your other READMEs — e.g., APB transfer phases, PSELx/PENABLE handshaking, PPROT security attributes, wait-state insertion, etc.)*

---

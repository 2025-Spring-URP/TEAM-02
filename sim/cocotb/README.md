rtl/
├── PCIE_PKG.sv              ← typedef, struct, enum 등

tb/
├── PCIE_VERIF_PKG.sv        ← class 정의 (transaction, driver, monitor 등)
├── env/
│   ├── pcie_txn.sv          ← class pcie_txn extends uvm_sequence_item ...
│   ├── pcie_driver.sv
│   └── pcie_monitor.sv

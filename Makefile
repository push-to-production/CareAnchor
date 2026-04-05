# Care Anchor — developer tooling
#
# Quick start for new devs:
#   make deps        # install Python deps
#   make icd-data    # download ICD-10-CM 2026 code file from CMS
#   make icd-index   # build semantic RAG index (~60-90 s first run)
#   make dev         # start the Jac dev server

PYTHON    ?= python3
DATA_DIR  := data
ICD_FILE  := $(DATA_DIR)/icd10cm_codes_2026.txt
INDEX_PKL := $(DATA_DIR)/.icd_semantic_index.pkl
SYMPTOM_CSV := $(DATA_DIR)/.symptom_dataset.csv

# CMS April 2026 release — code descriptions (tabular order)
ICD_ZIP_URL := https://www.cms.gov/files/zip/april-1-2026-code-descriptions-tabular-order.zip
ICD_ZIP     := /tmp/icd10cm_2026.zip

.PHONY: all deps icd-data icd-index clean-index clean dev help

all: deps icd-data icd-index

## install Python dependencies
deps:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install sentence-transformers numpy requests

## download ICD-10-CM 2026 code file from CMS (requires internet)
icd-data: $(ICD_FILE)

$(ICD_FILE):
	@echo "Downloading ICD-10-CM 2026 from CMS..."
	@curl -L --progress-bar -o $(ICD_ZIP) "$(ICD_ZIP_URL)" || \
	  { echo ""; echo "ERROR: Download failed."; \
	    echo "Manual steps:"; \
	    echo "  1. Visit https://www.cms.gov/medicare/coding-billing/icd-10-codes/2026-icd-10-cm"; \
	    echo "  2. Download 'Code Descriptions in Tabular Order'"; \
	    echo "  3. Unzip and copy icd10cm_codes_2026.txt to $(DATA_DIR)/"; \
	    exit 1; }
	@echo "Extracting icd10cm_codes_2026.txt..."
	@unzip -p $(ICD_ZIP) "icd10cm_codes_2026.txt" > $(ICD_FILE) || \
	  unzip -j $(ICD_ZIP) "*/icd10cm_codes_2026.txt" -d $(DATA_DIR)/
	@rm -f $(ICD_ZIP)
	@echo "ICD-10-CM data ready: $(ICD_FILE)"

## build the semantic RAG index (sentence-transformers + HuggingFace symptom dataset)
## produces: data/.icd_semantic_index.pkl  data/.symptom_dataset.csv
icd-index: $(INDEX_PKL)

$(INDEX_PKL): $(ICD_FILE)
	@echo "Building semantic ICD index — this takes ~60-90 s on first run..."
	$(PYTHON) -c "import sys; sys.path.insert(0, '.'); \
	  from data.icd_rag import warm_up; \
	  n = warm_up(); \
	  print(f'Index ready: {n:,} codes')"
	@echo "Done. Index saved to $(INDEX_PKL)"

## delete generated index files (forces a full rebuild on next make icd-index)
clean-index:
	rm -f $(INDEX_PKL) $(SYMPTOM_CSV)
	@echo "Index files removed. Run 'make icd-index' to rebuild."

## delete all generated artifacts including the ICD source data
clean: clean-index
	rm -f $(ICD_FILE)
	@echo "All generated data removed."

## start the Jac development server
dev:
	jac start main.jac

## print usage
help:
	@echo ""
	@echo "Care Anchor — Makefile targets"
	@echo "================================"
	@echo "  make deps        Install Python dependencies (sentence-transformers, numpy)"
	@echo "  make icd-data    Download ICD-10-CM 2026 codes from CMS (~4 MB)"
	@echo "  make icd-index   Build semantic RAG index from ICD data + HuggingFace dataset"
	@echo "  make all         Run deps + icd-data + icd-index in sequence"
	@echo "  make clean-index Remove generated index files (icd-index will rebuild)"
	@echo "  make clean       Remove all generated data including ICD source file"
	@echo "  make dev         Start the Jac dev server (jac start main.jac)"
	@echo ""
	@echo "First-time setup:"
	@echo "  make all && make dev"
	@echo ""
	@echo "Files managed by this Makefile (gitignored):"
	@echo "  $(ICD_FILE)    — 74,719 ICD-10-CM code descriptions"
	@echo "  $(INDEX_PKL)   — semantic embedding matrix"
	@echo "  $(SYMPTOM_CSV) — disease-symptom dataset cache"
	@echo ""

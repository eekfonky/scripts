.PHONY: help install install-dev test lint lint-python lint-shell format clean setup-hooks

help:
	@echo "Available targets:"
	@echo "  install        - Install Python dependencies"
	@echo "  install-dev    - Install Python development dependencies"
	@echo "  setup-hooks    - Install pre-commit hooks"
	@echo "  test           - Run tests"
	@echo "  lint           - Run all linters (Python + Shell)"
	@echo "  lint-python    - Run Python linters"
	@echo "  lint-shell     - Run shellcheck on bash scripts"
	@echo "  format         - Format Python code with black"
	@echo "  clean          - Remove temporary files and caches"

install:
	pip install -r requirements.txt

install-dev:
	pip install -r requirements-dev.txt

setup-hooks:
	pre-commit install
	@echo "Pre-commit hooks installed successfully"

test:
	@if [ -d "tests" ]; then \
		pytest tests/ -v; \
	else \
		echo "No tests directory found"; \
	fi

lint: lint-python lint-shell

lint-python:
	@echo "Running flake8..."
	flake8 *.py --max-line-length=100 --extend-ignore=E203,W503 || true
	@echo "Running black check..."
	black --check *.py --line-length=100 || true

lint-shell:
	@echo "Running shellcheck..."
	@for script in *.sh; do \
		if [ -f "$$script" ]; then \
			echo "Checking $$script..."; \
			shellcheck "$$script" || true; \
		fi \
	done

format:
	black *.py --line-length=100
	@echo "Python files formatted successfully"

clean:
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '.pytest_cache' -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true
	rm -f .coverage
	@echo "Cleaned up temporary files"

.PHONY: gifs logcopter-generate logcopter-check

all: gifs

VERSION=v0.1.14
GORELEASER_ARGS ?= --skip=sign --snapshot --clean
GORELEASER_TARGET ?= --single-target

TAPES=$(wildcard doc/vhs/*tape)
gifs: $(TAPES)
	for i in $(TAPES); do vhs < $$i; done

docker-lint:
	docker run --rm -v $(shell pwd):/app -w /app golangci/golangci-lint:latest golangci-lint run -v

lint:
	GOWORK=off golangci-lint run -v

lintmax:
	GOWORK=off golangci-lint run -v --max-same-issues=100

gosec:
	GOWORK=off go install github.com/securego/gosec/v2/cmd/gosec@latest
	gosec -exclude-generated -exclude=G101,G304,G301,G306 -exclude-dir=.history ./...

govulncheck:
	GOWORK=off go install golang.org/x/vuln/cmd/govulncheck@latest
	govulncheck ./...

test:
	GOWORK=off go test ./...

build:
	GOWORK=off go generate ./...
	GOWORK=off go build ./...

logcopter-generate:
	GOWORK=off go generate ./...

logcopter-check:
	GOWORK=off go tool logcopter-gen -area-prefix go-go-golems.golem-docs -strip-prefix github.com/go-go-golems/golem-docs -check ./pkg/...

goreleaser:
	GOWORK=off goreleaser release $(GORELEASER_ARGS) $(GORELEASER_TARGET)

# Validate the svu output before tagging: a bare `git tag` (empty argument)
# would just list tags and exit 0, silently skipping the release tag.
tag-major:
	@tag="$$(svu major)" && test -n "$$tag" && git tag "$$tag" && echo "Tagged $$tag"

tag-minor:
	@tag="$$(svu minor)" && test -n "$$tag" && git tag "$$tag" && echo "Tagged $$tag"

tag-patch:
	@tag="$$(svu patch)" && test -n "$$tag" && git tag "$$tag" && echo "Tagged $$tag"

release:
	git push origin --tags
	GOWORK=off GOPROXY=proxy.golang.org go list -m github.com/go-go-golems/golem-docs@$(shell svu current)

bump-go-go-golems:
	@deps="$$(awk '/^require[[:space:]]+github\.com\/go-go-golems\// { print $$2 } /^[[:space:]]*github\.com\/go-go-golems\// { print $$1 }' go.mod | sort -u)"; \
	if [ -z "$$deps" ]; then \
		echo "No github.com/go-go-golems dependencies in go.mod"; \
	else \
		echo "Bumping go-go-golems dependencies:"; \
		echo "$$deps"; \
		for dep in $$deps; do GOWORK=off go get "$${dep}@latest" || exit 1; done; \
	fi
	GOWORK=off go mod tidy

GOLEM_DOCS_BINARY=$(shell which golem-docs)
install:
	GOWORK=off go build -o ./dist/golem-docs ./cmd/golem-docs && \
		cp ./dist/golem-docs $(GOLEM_DOCS_BINARY)

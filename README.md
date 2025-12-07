Claude Agent Container Boilerplate

A Docker compose to run Claude Code in a container, with custom context and blocked internet access (except Anthropic domains).

Useful for running dangerous tasks in an isolated private environment.

```
docker exec <container> bash -c 'claude --dangerously-skip-permissions --output-format json --print "a dangerous task to do"'
```

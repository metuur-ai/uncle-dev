# Loop Engineering

## 1. Keep the context clean

Long loops rot — old outputs, dead ends, stale reasoning pile up. The agent gets dumber the longer it runs.

```
context rot →
[========        ]
[==============  ]
[================]   ───>   [  lean  ]
```

- **Compact** — summarize, then continue
- **Offload** — push big output to a file
- **Sub-agents** — isolate messy subtasks

## 2. Know when to stop

A terminal message ends the turn, not the job. Layer brakes so it stops for real reasons, not a vibe:

```
+---------------------------------------------+
| max iterations   -   hard cap               |
+---------------------------------------------+
| budget + time    -   token/$/sec            |
+---------------------------------------------+
| no-progress      -   same call & args       |
+---------------------------------------------+
| completion check -   tests pass ✓           |
+---------------------------------------------+
```

## 3. A critic that can say no

Left alone, an agent just agrees with itself. Separate the maker from the checker — one works, another grades:

```
+---------+               +---------+
|  Maker  | <===========> | Checker |
+---------+     "no"      +---------+
```

a test · a type-check · a real error

**It doesn't grade its own homework.**

## 4. Tools it can actually use

Pile on 100 tools and it loses track of which to reach for. A tight, non-overlapping set wins:

```
 (o) (o) (o)   few, focused ✓

     / / /
   (o) (o) (o)
   / / / / /     100 tools ✗
 (o) (o) (o)
```

- Few, focused, non-overlapping
- Make writes safe to repeat
- Errors written for the agent

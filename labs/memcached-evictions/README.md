# Lab: Memcached evicts before it looks full

Two Memcached nodes that share nothing. `cache-a` has a 32 MB limit and its own page mover switched off.
The seed fills every one of its pages with small session items, then lets two thirds of them expire, so
the node holds about a third of its limit in items while every page stays committed to the small items'
slab class. A background load then writes page fragments of about 2.4 KB to it. Their class can get no
page, so it evicts inside the one page it has, all the time, while the node's memory used reads far
below its limit. `cache-b` has a 64 MB limit, a working set that is read back, and no evictions.

**Edition:** requires BROKA Commercial.

## Requirements

- Docker with Compose v2
- BROKA Commercial running, for example from [`install/`](../../install/) with the Commercial images
- Host ports 11311 and 11312 free, or change them in `.env`

## Run

1. Optional: copy the settings file to change the ports, the expiry or the load:

   ```bash
   cp .env.example .env
   ```

2. Start both nodes, the seed and the load:

   ```bash
   docker compose up -d
   ```

   The seed takes about a minute: it fills `cache-a` until no page is left, waits for the expiring items to
   expire and asks the node to reclaim them. The load starts when it is done.

3. Check what the seed did:

   ```bash
   docker compose logs seed
   ```

   The last lines give each node's limit, item count, the bytes the items take as a share of the limit,
   evictions and expired-unread items.

To start over, run `bash scripts/reset.sh`. It restarts both nodes empty and seeds them again.

## Connect BROKA

Add a Memcached instance in BROKA:

| Field | Value |
|---|---|
| Name | `lab-memcached` |
| Nodes | `host.docker.internal:11311, host.docker.internal:11312` |

`host.docker.internal` works when BROKA runs on Docker Desktop. On Linux, use the host's IP address.
Memcached has no credentials to enter.

## What to look at

1. **Memcached ▸ Overview.** The tiles add the two nodes up. In the node table, `cache-a` (`:11311`)
   evicts and `cache-b` (`:11312`) does not, and `cache-a`'s memory used is well below its 32 MB. Its
   **Expired, never read** is large: the seed's expiring sessions were never read, and the load keeps
   adding short-lived ones.
2. **Memory & slabs**, node `:11311`. **Claimed from the OS** has reached the limit. In the **Pages**
   column the session items' class holds nearly all of them, with a low **Chunks used** and no
   evictions. The page fragments' class holds one page and its **Evicted** count keeps rising. **Chunk**
   and **Efficiency** show what each class rounds its items up to.
3. **Item sizes** shows two groups of items, around 100 bytes and around 2.5 KB. Both nodes were started
   with `-o track_sizes`.
4. **Rebalance ▸ Move a page** from the session class to the fragments' class. The node answers **OK**,
   and the next read of the table shows the page moved and the items that were on it gone. Other answers,
   such as **BUSY** while a move is still running, are reported as the node gave them.
5. **Let the node rebalance itself.** Set automove to **Standard** or **Aggressive** and watch pages leave
   the session class over the next minutes. The node does not report its mode back.
6. **Reclaim expired items.** The load writes ten sessions a second that live ten seconds and are never
   read; the reclaim reports how many expired items the walk freed.
7. **Nodes ▸ Memory limit.** Raise `cache-a`'s limit to 64 MB: the fragments' class takes new pages and the
   evictions stop within seconds. Lower `cache-b`'s from 64 MB to 8 MB: the dialog warns. The node keeps the
   pages it already holds and takes no new ones, so the next writes that need room evict. Send some:

   ```bash
   docker compose exec cache-b sh -c "awk 'BEGIN { for (i = 0; i < 3000; i++) printf \"set extra:%d 0 0 500 noreply\r\n%500s\r\n\", i, \"\"; printf \"quit\r\n\" }' | nc 127.0.0.1 11211"
   ```
8. **Reset counters** on a node restarts its rates from zero without touching an item.
9. **Live events**, node `:11311`, **Evictions** ticked: evictions arrive as the load causes them.
   **Deletions** stays quiet, because nothing deletes.

The table's **Out of memory** column stays at 0: this lab does not produce a class that refuses a store
outright.

## Clean up

```bash
docker compose down -v
```

## Guide

[Memcached evicts before it looks full](https://broka.dev/guides/memcached-evicts-before-it-looks-full)

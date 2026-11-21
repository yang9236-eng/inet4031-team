# Networking and Cloud Infrastructure

## Week 11 request path

1. k6 runs on the Ubuntu VM and sends GET / to the web Service at 10.43.229.24:8080.
2. The web Service routes the request to a ready Flask web pod.
3. Flask reads the tickets from PostgreSQL through the db Service on port 5432.
4. The db Service routes the connection to the PostgreSQL pod. The db-clients
   NetworkPolicy controls which pods can connect to it.
5. Flask returns the page to the k6 client.

## Baseline

The two-minute k6 run completed 2,170 requests at 18.07 requests/sec,
with a p95 response time of 19.85 ms and zero failed requests.
Before the test, one web replica was ready and using 23 MiB of memory.
Its configured memory request was 64 MiB and its limit was 256 MiB.

## Planned app change

For the rollout drill, I plan to make a small visible change to the
incident tracker page heading so I can verify that the new image is serving.

# Bench suite 

Using the repo https://github.com/asoorm/go-bench-suite to add more options to test Tyk
gateway with another upstream except httpbin.

## Bootstrap

- Run the `up.sh` script with the `bench` parameter:

```bash
./up.sh bench
```

## Usage

Note: The bench suite is exposed on port 8889 and internally on port 8000

- To test and compare response time with and without Tyk in the middle:

  - Install hey, a tiny program to do some load to a web application
    `brew install hey`

  - Test the upstream bench suite
    ```
    hey -n 2000 http://bench:8889/json/valid -H "X-Delay: 2s"
    ```

  - Test the response time with Tyk in the middle, using the api `/bench-uptream`:
    ```
    hey -n 2000 http://tyk-gateway.localhost:8080/bench-uptream/json/valid -H "X-Delay: 2s" -m GET
    ```

- Compare the results

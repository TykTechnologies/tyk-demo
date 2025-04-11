echo "Testing hmac-based auth..."
./deployments/plugin-python-grpc/scripts/hmac.sh

if [ $? -eq 0 ]; then
    echo "HMAC-based auth test passed"
else
    echo "HMAC-based auth test failed"
    exit 1
fi
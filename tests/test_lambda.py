import json
import importlib.util
from unittest.mock import patch

# Dynamically import func.py from the 'lambda' directory to avoid keyword conflicts
spec = importlib.util.spec_from_file_location("func", "lambda/func.py")
func_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(func_module)

lambda_handler = func_module.lambda_handler


@patch.object(func_module, 'table')
def test_lambda_handler_success(mock_table):
    # 1. Arrange: Mock DynamoDB update_item return value
    mock_table.update_item.return_value = {
        'Attributes': {
            'count': 42
        }
    }

    event = {}
    context = {}

    # 2. Act: Call the handler
    response = lambda_handler(event, context)

    # 3. Assert: Check statusCode, CORS headers, and counter value
    assert response['statusCode'] == 200
    assert response['headers']['Access-Control-Allow-Origin'] == '*'

    body = json.loads(response['body'])
    assert body['views'] == 42

    mock_table.update_item.assert_called_once()
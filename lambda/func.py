import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-visitor-count')


def lambda_handler(event, context):
    # Atomic increment of the visitor count
    response = table.update_item(
        Key={'id': 'visitors'},
        UpdateExpression='ADD #c :val',
        ExpressionAttributeNames={'#c': 'count'},
        ExpressionAttributeValues={':val': 1},
        ReturnValues='UPDATED_NEW'
    )

    views = int(response['Attributes']['count'])

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        'body': json.dumps({'views': views})
    }
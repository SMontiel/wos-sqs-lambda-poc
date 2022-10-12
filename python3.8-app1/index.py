import json


def lambda_handler(event, context):
    print("Hello from app1!")
    print(str(event))

    for record in event["Records"]:
        sns = record["Sns"]
        subject = sns["Subject"]
        message = sns["Message"]

        if sns["Subject"].startswith(('ALARM: "', 'OK: "')):
            message_json = json.loads(sns["Message"])
            state = message_json["NewStateValue"]
            queue = message_json["Trigger"]["Dimensions"][0]["value"]
            if state == "OK":
                subject = f"Queue {queue} is empty"
                message = f"Everything is OK, the queue {queue} is empty."
                # set color to green
            else:
                subject = f":alert: Queue {queue} is NOT empty"
                message = message_json["AlarmDescription"] + f". Please, review it here: https://us-west-1.console.aws.amazon.com/sqs/v2/home#/queues/https%3A%2F%2Fsqs.us-west-1.amazonaws.com%2F205399592845%2F{queue}"
                # set color to red

        print(subject)
        print(message)

    return {
        "event": str(event)
    }

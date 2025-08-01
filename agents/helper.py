import json

class Helper:
    def __init__(self):
        pass
    
    def read_ids(self, filename = 'bug_ids.txt'):
        with open(filename, 'r') as f:
            ids = f.readlines()
            ids = [x.strip() for x in ids]
            return ids

    def read_bug_report(self, id, filename='bug_reports.json'):
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data[id]
        
    def read_commit(self, id, filename='commits.json'):
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data[id]
    
    def read_digest(self, id):
        with open(f'{id}_digest.json', 'r') as f:
            return json.load(f)
        
    def read_analysis(self, id):
        with open(f'{id}_analysis.md', 'r', encoding='utf-8') as f:
            return f.read()
        
    def generate_digest(self, report, response):
        filename = report['id'] + "_digest.json"
        # filename = "./reports_r1/" + filename
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(json.loads(response.choices[0].message.content), f, indent=4)
        
        print(f"Digested the bug report and generate results: {filename}")

    def generate_analysis_report(self, report, response):
        filename = (report['id'][:10] if len(report['id']) > 10 else report['id']) + "_analysis.md"
        # filename = "./reports_r1/" + filename
        with open(filename, "w", encoding="utf-8") as f:
            # f.write("[Reasoning process]\n")
            # f.write(response.choices[0].message.reasoning_content)
            f.write("[Generated summary]\n")
            f.write(response.choices[0].message.content)

        print(f"Analysed the bug report and generate results: {filename}")

    def generate_analysis_report_stream(self, report, response):
        if type(report['id']) == int:
            report['id'] = str(report['id'])
        filename = (report['id'][:10] if len(report['id']) > 10 else report['id']) + "_analysis.md"
        # filename = "./reports_r1/" + filename
        reasoning_content = ""
        answer_content = ""
        with open(filename, "w", encoding="utf-8") as f:
            for chunk in response:
                if hasattr(chunk.choices[0].delta, 'reasoning_content') and chunk.choices[0].delta.reasoning_content:
                    reasoning_content += chunk.choices[0].delta.reasoning_content
                if hasattr(chunk.choices[0].delta, 'content') and chunk.choices[0].delta.content:
                    answer_content += chunk.choices[0].delta.content
            f.write("[Reasoning process]\n")
            f.write(reasoning_content)
            f.write("\n\n[Generated summary]\n")
            f.write(answer_content)        
        print(f"Analysed the bug report and generate results: {filename}")

    def generate_evaluation(self, id, response):
        filename = id + "_evaluation.md"

        with open(filename, "w", encoding="utf-8") as f:
            f.write(response.choices[0].message.content)
        
        print(f"Evaluated the result and generate file: {filename}")

    
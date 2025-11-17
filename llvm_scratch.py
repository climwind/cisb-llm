import requests
import json
import time
import os
from urllib.parse import urlencode

# 配置
GITHUB_API_BASE = "https://api.github.com"
SEARCH_QUERY = "is:issue is:closed repo:llvm/llvm-project label:invalid NOT \"error\" label:bugzilla label:clang:codegen,c,clang,llvm:optimizations,llvm:codegen,\"undefined behaviour\",loopoptim sort:created-asc"
PER_PAGE = 100  # 每页最大 100 条
OUTPUT_FILE = "llvm_issues_part1.json"
IDS_FILE = "llvm_issue_ids.txt"
KEYWORD_SEARCH = False  # 是否先进行关键词搜索过滤
# GitHub 个人访问令牌（支持 fine-grained PAT）
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")  # 或直接填入："github_pat_..."

# 请求头
headers = {
    "Accept": "application/vnd.github+json",
}
if GITHUB_TOKEN:
    headers["Authorization"] = f"token {GITHUB_TOKEN}"

def handle_rate_limit(response):
    """处理 API 限额"""
    if response.status_code == 403 and "X-RateLimit-Remaining" in response.headers:
        if int(response.headers["X-RateLimit-Remaining"]) == 0:
            reset_time = int(response.headers["X-RateLimit-Reset"])
            wait_time = max(0, reset_time - time.time()) + 5
            print(f"超过限额，等待 {wait_time:.0f} 秒...")
            time.sleep(wait_time)
            return True
    return False

def make_request(url, params=None):
    """发送 API 请求，处理限额和错误"""
    while True:
        try:
            response = requests.get(url, headers=headers, params=params)
            if handle_rate_limit(response):
                continue
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"请求 {url} 失败：{e}")
            time.sleep(2)
            continue

def get_all_search_results():
    """获取所有搜索结果的 Issue ID"""
    issue_ids = []
    page = 1
    while True:
        print(f"获取第 {page} 页搜索结果...")
        params = {
            "q": SEARCH_QUERY,
            "per_page": PER_PAGE,
            "page": page,
        }
        url = f"{GITHUB_API_BASE}/search/issues"
        data = make_request(url, params)
        
        issues = data.get("items", [])
        if not issues:
            break
        issue_ids.extend(issue["number"] for issue in issues)
        
        if data["total_count"] <= page * PER_PAGE:
            break
        page += 1
        time.sleep(1)
        
    print(f"找到 {len(issue_ids)} 个 Issue")
    return issue_ids

def get_issue_details(issue_id):
    """获取单个 Issue 的详细信息，标注评论"""
    print(f"获取 Issue #{issue_id} 的详情...")
    issue_url = f"{GITHUB_API_BASE}/repos/llvm/llvm-project/issues/{issue_id}"
    issue_data = make_request(issue_url)
    
    # 获取 Issue 创建者
    issuer = issue_data.get("user", {}).get("login", "")
    
    # 获取所有评论
    comments = []

    # 添加 Issue 正文
    issue_body = issue_data.get("body", "")
    # if issue_body:
    #     comments.append(f"[Issuer] {issue_body}")

    page = 1
    while True:
        comments_url = f"{issue_url}/comments"
        params = {"per_page": PER_PAGE, "page": page}
        comments_data = make_request(comments_url, params)
        if not comments_data:
            break
        for comment in comments_data:
            commenter = comment.get("user", {}).get("login", "")
            comment_body = comment.get("body", "")
            # 添加标注
            if commenter == issuer:
                annotated_body = f"[Issuer] {comment_body}"
            else:
                annotated_body = f"[Developer] {comment_body}"
            comments.append(annotated_body)
        page += 1
        time.sleep(1)
    
    return {
        "id": issue_id,
        "title": issue_data.get("title", ""),
        "issue body": issue_body,
        "comments": comments,
    }


def main():
    """主函数，提取 Issues 并保存为 JSON"""
    if KEYWORD_SEARCH:
        issue_ids = get_all_search_results()
    else:
        issue_ids = open(IDS_FILE, "r", encoding="utf-8").read().splitlines()
        
    all_issues = {}
    for issue_id in issue_ids:
        issue_details = get_issue_details(issue_id)
        all_issues[issue_id] = issue_details
        time.sleep(1)
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_issues, f, indent=4, ensure_ascii=False)
    
    with open(IDS_FILE, "w", encoding="utf-8") as f:
        for issue_id in issue_ids:
            f.write(f"{issue_id}\n")

    print(f"已保存 {len(all_issues)} 个 Issue 到 {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
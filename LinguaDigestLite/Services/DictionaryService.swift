//
//  DictionaryService.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation
import UIKit
import NaturalLanguage

/// 词典服务
class DictionaryService {
    static let shared = DictionaryService()

    private init() {}

    private let irregularWordForms: [String: [String]] = [
        "am": ["be"], "is": ["be"], "are": ["be"], "was": ["be"], "were": ["be"], "been": ["be"], "being": ["be"],
        "has": ["have"], "had": ["have"], "having": ["have"],
        "does": ["do"], "did": ["do"], "done": ["do"], "doing": ["do"],
        "goes": ["go"], "went": ["go"], "gone": ["go"],
        "says": ["say"], "said": ["say"],
        "gets": ["get"], "got": ["get"], "gotten": ["get"], "getting": ["get"],
        "makes": ["make"], "made": ["make"], "making": ["make"],
        "takes": ["take"], "took": ["take"], "taken": ["take"], "taking": ["take"],
        "sees": ["see"], "saw": ["see"], "seen": ["see"], "seeing": ["see"],
        "comes": ["come"], "came": ["come"], "coming": ["come"],
        "thinks": ["think"], "thought": ["think"], "thinking": ["think"],
        "finds": ["find"], "found": ["find"], "finding": ["find"],
        "tells": ["tell"], "told": ["tell"], "telling": ["tell"],
        "feels": ["feel"], "felt": ["feel"], "feeling": ["feel"],
        "leaves": ["leave"], "left": ["leave"], "leaving": ["leave"],
        "keeps": ["keep"], "kept": ["keep"], "keeping": ["keep"],
        "begins": ["begin"], "began": ["begin"], "begun": ["begin"], "beginning": ["begin"],
        "hears": ["hear"], "heard": ["hear"], "hearing": ["hear"],
        "runs": ["run"], "ran": ["run"], "running": ["run"],
        "holds": ["hold"], "held": ["hold"], "holding": ["hold"],
        "brings": ["bring"], "brought": ["bring"], "bringing": ["bring"],
        "writes": ["write"], "wrote": ["write"], "written": ["write"], "writing": ["write"],
        "sits": ["sit"], "sat": ["sit"], "sitting": ["sit"],
        "stands": ["stand"], "stood": ["stand"], "standing": ["stand"],
        "pays": ["pay"], "paid": ["pay"], "paying": ["pay"],
        "meets": ["meet"], "met": ["meet"], "meeting": ["meet"],
        "sets": ["set"], "setting": ["set"],
        "learns": ["learn"], "learned": ["learn"], "learnt": ["learn"], "learning": ["learn"],
        "leads": ["lead"], "led": ["lead"], "leading": ["lead"],
        "understands": ["understand"], "understood": ["understand"], "understanding": ["understand"],
        "speaks": ["speak"], "spoke": ["speak"], "spoken": ["speak"], "speaking": ["speak"],
        "reads": ["read"], "reading": ["read"],
        "spends": ["spend"], "spent": ["spend"], "spending": ["spend"],
        "grows": ["grow"], "grew": ["grow"], "grown": ["grow"], "growing": ["grow"],
        "wins": ["win"], "won": ["win"], "winning": ["win"],
        "buys": ["buy"], "bought": ["buy"], "buying": ["buy"],
        "sends": ["send"], "sent": ["send"], "sending": ["send"],
        "builds": ["build"], "built": ["build"], "building": ["build"],
        "falls": ["fall"], "fell": ["fall"], "fallen": ["fall"], "falling": ["fall"],
        "reaches": ["reach"], "reached": ["reach"], "reaching": ["reach"],
        "raises": ["raise"], "raised": ["raise"], "raising": ["raise"],
        "sells": ["sell"], "sold": ["sell"], "selling": ["sell"],
        "decides": ["decide"], "decided": ["decide"], "deciding": ["decide"],
        "children": ["child"], "men": ["man"], "women": ["woman"], "people": ["person"],
        "teeth": ["tooth"], "feet": ["foot"], "mice": ["mouse"], "geese": ["goose"],
        "better": ["good"], "best": ["good"], "worse": ["bad"], "worst": ["bad"],
        "farther": ["far"], "further": ["far"], "farthest": ["far"], "furthest": ["far"]
    ]

    // MARK: - 简易英汉词典

    /// 常用单词的中文释义（精选高频词汇）
    private let simpleDictionary: [String: (pos: String?, definition: String)] = [
        // 常用名词
        "time": ("名词", "时间；时候；时刻"),
        "year": ("名词", "年；年度"),
        "people": ("名词", "人们；人民"),
        "way": ("名词", "方式；道路；方法"),
        "day": ("名词", "天；日子"),
        "man": ("名词", "男人；人类"),
        "world": ("名词", "世界；地球"),
        "life": ("名词", "生活；生命"),
        "hand": ("名词", "手；帮助"),
        "part": ("名词", "部分；角色"),
        "child": ("名词", "孩子；儿童"),
        "place": ("名词", "地方；位置"),
        "case": ("名词", "案例；情况"),
        "week": ("名词", "周；星期"),
        "company": ("名词", "公司；企业"),
        "system": ("名词", "系统；制度"),
        "program": ("名词", "程序；计划"),
        "question": ("名词", "问题；疑问"),
        "work": ("名词", "工作；作品"),
        "government": ("名词", "政府"),
        "number": ("名词", "数字；号码"),
        "night": ("名词", "夜晚；晚上"),
        "point": ("名词", "点；观点；要点"),
        "home": ("名词", "家；家庭"),
        "water": ("名词", "水"),
        "room": ("名词", "房间；空间"),
        "area": ("名词", "区域；面积"),
        "money": ("名词", "钱；金钱"),
        "story": ("名词", "故事；小说"),
        "fact": ("名词", "事实；真相"),
        "month": ("名词", "月"),
        "lot": ("名词", "很多；份额"),
        "right": ("名词/形容词", "权利；正确的"),
        "study": ("名词/动词", "学习；研究"),
        "book": ("名词", "书；书籍"),
        "job": ("名词", "工作；职业"),
        "word": ("名词", "单词；话语"),
        "business": ("名词", "商业；生意"),
        "issue": ("名词", "问题；议题"),
        "side": ("名词", "边；方面"),
        "kind": ("名词", "种类；类型"),
        "head": ("名词", "头；领导者"),
        "house": ("名词", "房子"),
        "service": ("名词", "服务"),
        "friend": ("名词", "朋友"),
        "father": ("名词", "父亲"),
        "power": ("名词", "力量；权力"),
        "hour": ("名词", "小时"),
        "game": ("名词", "游戏；比赛"),
        "line": ("名词", "线；行列"),
        "end": ("名词", "结束；终点"),
        "member": ("名词", "成员"),
        "law": ("名词", "法律"),
        "car": ("名词", "汽车"),
        "city": ("名词", "城市"),
        "community": ("名词", "社区"),
        "name": ("名词", "名字；名称"),
        "president": ("名词", "总统；主席"),
        "team": ("名词", "团队"),
        "minute": ("名词", "分钟"),
        "idea": ("名词", "想法；主意"),
        "kid": ("名词", "小孩"),
        "body": ("名词", "身体"),
        "information": ("名词", "信息"),
        "back": ("名词", "后面；背部"),
        "parent": ("名词", "父母"),
        "face": ("名词", "脸；面对"),
        "others": ("名词", "其他人"),
        "level": ("名词", "水平；级别"),
        "office": ("名词", "办公室"),
        "door": ("名词", "门"),
        "health": ("名词", "健康"),
        "person": ("名词", "人"),
        "art": ("名词", "艺术"),
        "war": ("名词", "战争"),
        "history": ("名词", "历史"),
        "party": ("名词", "派对；政党"),
        "result": ("名词", "结果"),
        "change": ("名词/动词", "变化；改变"),
        "morning": ("名词", "早晨"),
        "reason": ("名词", "原因；理由"),
        "research": ("名词", "研究"),
        "girl": ("名词", "女孩"),
        "guy": ("名词", "家伙"),
        "moment": ("名词", "时刻；瞬间"),
        "air": ("名词", "空气"),
        "teacher": ("名词", "老师"),
        "force": ("名词", "力量；强制"),
        "education": ("名词", "教育"),
        "foot": ("名词", "脚"),
        "boy": ("名词", "男孩"),
        "age": ("名词", "年龄"),
        "policy": ("名词", "政策"),
        "process": ("名词", "过程"),
        "music": ("名词", "音乐"),
        "market": ("名词", "市场"),

        // 常用动词
        "be": ("动词", "是；存在"),
        "have": ("动词", "有；拥有"),
        "do": ("动词", "做；执行"),
        "say": ("动词", "说"),
        "get": ("动词", "得到；获得"),
        "make": ("动词", "制造；做"),
        "go": ("动词", "去；走"),
        "know": ("动词", "知道"),
        "take": ("动词", "拿；取"),
        "see": ("动词", "看见"),
        "come": ("动词", "来"),
        "think": ("动词", "思考；认为"),
        "look": ("动词", "看；看起来"),
        "want": ("动词", "想要"),
        "give": ("动词", "给"),
        "use": ("动词", "使用"),
        "find": ("动词", "找到"),
        "tell": ("动词", "告诉"),
        "ask": ("动词", "问；请求"),
        // work 已在上方定义
        "seem": ("动词", "似乎；看起来"),
        "feel": ("动词", "感觉"),
        "try": ("动词", "尝试"),
        "leave": ("动词", "离开"),
        "call": ("动词", "叫；打电话"),
        "should": ("动词", "应该"),
        "need": ("动词", "需要"),
        "become": ("动词", "成为"),
        "put": ("动词", "放"),
        "mean": ("动词", "意思是"),
        "keep": ("动词", "保持"),
        "let": ("动词", "让"),
        "begin": ("动词", "开始"),
        // seem 已在上方定义
        "help": ("动词", "帮助"),
        "show": ("动词", "展示；显示"),
        "hear": ("动词", "听到"),
        "play": ("动词", "玩；播放"),
        "run": ("动词", "跑；运行"),
        "move": ("动词", "移动"),
        "like": ("动词", "喜欢"),
        "live": ("动词", "居住；生活"),
        "believe": ("动词", "相信"),
        "hold": ("动词", "握住；举行"),
        "bring": ("动词", "带来"),
        "happen": ("动词", "发生"),
        "must": ("动词", "必须"),
        "write": ("动词", "写"),
        "provide": ("动词", "提供"),
        "sit": ("动词", "坐"),
        "stand": ("动词", "站立"),
        "lose": ("动词", "丢失"),
        "pay": ("动词", "支付"),
        "meet": ("动词", "遇见"),
        "include": ("动词", "包括"),
        "continue": ("动词", "继续"),
        "set": ("动词", "设置"),
        "learn": ("动词", "学习"),
        // change 已在上方定义
        "lead": ("动词", "领导；导致"),
        "understand": ("动词", "理解"),
        "watch": ("动词", "观看"),
        "follow": ("动词", "跟随"),
        "stop": ("动词", "停止"),
        "create": ("动词", "创造"),
        "speak": ("动词", "说话"),
        "read": ("动词", "阅读"),
        "allow": ("动词", "允许"),
        "add": ("动词", "添加"),
        "spend": ("动词", "花费"),
        "grow": ("动词", "生长"),
        // open 已在上方定义
        "walk": ("动词", "走路"),
        "win": ("动词", "赢得"),
        "offer": ("动词", "提供"),
        "remember": ("动词", "记住"),
        "love": ("动词", "爱"),
        "consider": ("动词", "考虑"),
        "appear": ("动词", "出现"),
        "buy": ("动词", "购买"),
        "wait": ("动词", "等待"),
        "serve": ("动词", "服务"),
        "die": ("动词", "死亡"),
        "send": ("动词", "发送"),
        "expect": ("动词", "期望"),
        "build": ("动词", "建造"),
        "stay": ("动词", "停留"),
        "fall": ("动词", "落下"),
        "cut": ("动词", "切；剪"),
        "reach": ("动词", "到达"),
        "kill": ("动词", "杀死"),
        "remain": ("动词", "保持"),
        "suggest": ("动词", "建议"),
        "raise": ("动词", "举起；提高"),
        "pass": ("动词", "通过"),
        "sell": ("动词", "出售"),
        "require": ("动词", "要求"),
        // report 已在下方新闻词汇部分定义
        "decide": ("动词", "决定"),
        "pull": ("动词", "拉"),
        "develop": ("动词", "发展"),

        // 常用形容词
        "good": ("形容词", "好的"),
        "new": ("形容词", "新的"),
        "first": ("形容词", "第一个"),
        "last": ("形容词", "最后的"),
        "long": ("形容词", "长的"),
        "great": ("形容词", "伟大的；极好的"),
        "little": ("形容词", "小的；少的"),
        "own": ("形容词", "自己的"),
        "other": ("形容词", "其他的"),
        "old": ("形容词", "旧的；老的"),
        // right 已在上方定义
        "big": ("形容词", "大的"),
        "high": ("形容词", "高的"),
        "different": ("形容词", "不同的"),
        "small": ("形容词", "小的"),
        "large": ("形容词", "大的"),
        "next": ("形容词", "下一个"),
        "early": ("形容词", "早的"),
        "young": ("形容词", "年轻的"),
        "important": ("形容词", "重要的"),
        "few": ("形容词", "很少的"),
        "public": ("形容词", "公共的"),
        "bad": ("形容词", "坏的"),
        "same": ("形容词", "相同的"),
        "able": ("形容词", "能够的"),
        "free": ("形容词", "自由的；免费的"),
        "ready": ("形容词", "准备好的"),
        "clear": ("形容词", "清楚的"),
        // open 已在上方定义
        "simple": ("形容词", "简单的"),
        "happy": ("形容词", "快乐的"),
        "main": ("形容词", "主要的"),
        "true": ("形容词", "真实的"),
        "whole": ("形容词", "整个的"),
        "sure": ("形容词", "确定的"),
        "full": ("形容词", "满的"),
        "special": ("形容词", "特别的"),
        "better": ("形容词", "更好的"),
        "best": ("形容词", "最好的"),
        "real": ("形容词", "真实的"),
        "strong": ("形容词", "强壮的"),
        "possible": ("形容词", "可能的"),
        "nice": ("形容词", "好的；友善的"),
        "serious": ("形容词", "严肃的"),
        "beautiful": ("形容词", "美丽的"),
        "political": ("形容词", "政治的"),
        "common": ("形容词", "普通的"),
        "natural": ("形容词", "自然的"),
        "hot": ("形容词", "热的"),
        "cold": ("形容词", "冷的"),
        "dark": ("形容词", "黑暗的"),
        "bright": ("形容词", "明亮的"),
        "safe": ("形容词", "安全的"),
        "easy": ("形容词", "容易的"),
        "hard": ("形容词", "困难的；硬的"),
        "popular": ("形容词", "流行的"),
        "interesting": ("形容词", "有趣的"),
        "surprising": ("形容词", "令人惊讶的"),
        "amazing": ("形容词", "令人惊叹的"),
        "difficult": ("形容词", "困难的"),
        "modern": ("形容词", "现代的"),
        "traditional": ("形容词", "传统的"),
        "global": ("形容词", "全球的"),
        "local": ("形容词", "当地的"),
        "national": ("形容词", "国家的"),
        "international": ("形容词", "国际的"),
        "economic": ("形容词", "经济的"),
        "financial": ("形容词", "金融的"),
        "social": ("形容词", "社会的"),
        "personal": ("形容词", "个人的"),
        "professional": ("形容词", "专业的"),
        "technical": ("形容词", "技术的"),
        "scientific": ("形容词", "科学的"),
        "medical": ("形容词", "医学的"),
        "educational": ("形容词", "教育的"),
        "digital": ("形容词", "数字的"),
        "electric": ("形容词", "电的"),
        "physical": ("形容词", "物理的；身体的"),
        "mental": ("形容词", "精神的；心理的"),
        "emotional": ("形容词", "情感的"),
        "positive": ("形容词", "积极的"),
        "negative": ("形容词", "消极的"),
        "successful": ("形容词", "成功的"),
        "creative": ("形容词", "有创造力的"),
        "available": ("形容词", "可用的"),
        "relevant": ("形容词", "相关的"),
        "significant": ("形容词", "重要的"),
        "recent": ("形容词", "最近的"),
        "current": ("形容词", "当前的"),

        // 常用副词
        "more": ("副词", "更多"),
        "also": ("副词", "也"),
        "very": ("副词", "非常"),
        "just": ("副词", "只是；刚刚"),
        "then": ("副词", "然后"),
        "well": ("副词", "好；很好地"),
        "how": ("副词", "如何"),
        "now": ("副词", "现在"),
        "really": ("副词", "真的"),
        "here": ("副词", "这里"),
        "there": ("副词", "那里"),
        "always": ("副词", "总是"),
        "never": ("副词", "从不"),
        "often": ("副词", "经常"),
        "sometimes": ("副词", "有时"),
        "usually": ("副词", "通常"),
        "already": ("副词", "已经"),
        "still": ("副词", "仍然"),
        "again": ("副词", "再次"),
        "maybe": ("副词", "也许"),
        "perhaps": ("副词", "可能"),
        "probably": ("副词", "大概"),
        "certainly": ("副词", "肯定"),
        "actually": ("副词", "实际上"),
        "finally": ("副词", "最终"),
        "recently": ("副词", "最近"),
        "quickly": ("副词", "快速地"),
        "slowly": ("副词", "慢慢地"),
        "carefully": ("副词", "仔细地"),
        "easily": ("副词", "容易地"),
        "clearly": ("副词", "清楚地"),
        "simply": ("副词", "简单地"),
        "especially": ("副词", "尤其"),
        "particularly": ("副词", "特别"),
        "exactly": ("副词", "确切地"),
        "almost": ("副词", "几乎"),
        "completely": ("副词", "完全"),
        "totally": ("副词", "完全"),
        "extremely": ("副词", "极其"),
        "absolutely": ("副词", "绝对"),

        // 常用介词/连词等
        "about": ("介词", "关于"),
        "after": ("介词", "在...之后"),
        "before": ("介词", "在...之前"),
        "between": ("介词", "在...之间"),
        "under": ("介词", "在...下面"),
        "above": ("介词", "在...上面"),
        "through": ("介词", "通过"),
        "during": ("介词", "在...期间"),
        "within": ("介词", "在...之内"),
        "without": ("介词", "没有"),
        "around": ("介词", "围绕"),
        "among": ("介词", "在...之中"),
        "against": ("介词", "反对；依靠"),
        "along": ("介词", "沿着"),
        "across": ("介词", "穿过"),
        "behind": ("介词", "在...后面"),
        "beside": ("介词", "在...旁边"),
        "toward": ("介词", "朝向"),
        "upon": ("介词", "在...之上"),
        "into": ("介词", "进入"),
        "onto": ("介词", "到...上"),
        "from": ("介词", "从"),
        "with": ("介词", "和...一起；用"),
        "by": ("介词", "通过；被"),
        "of": ("介词", "的"),
        "in": ("介词", "在...里面"),
        "on": ("介词", "在...上面"),
        "at": ("介词", "在"),
        "to": ("介词", "到；向"),
        "for": ("介词", "为了"),
        "as": ("介词/连词", "作为；像"),
        "if": ("连词", "如果"),
        "because": ("连词", "因为"),
        "although": ("连词", "虽然"),
        "though": ("连词", "虽然"),
        "while": ("连词", "当...时"),
        "when": ("连词", "当...时"),
        "where": ("连词", "哪里"),
        "why": ("连词", "为什么"),
        "who": ("连词", "谁"),
        "what": ("连词", "什么"),
        "which": ("连词", "哪一个"),
        "that": ("连词", "那个"),
        "this": ("代词", "这个"),
        "these": ("代词", "这些"),
        "those": ("代词", "那些"),
        "all": ("代词/形容词", "所有"),
        "each": ("代词", "每个"),
        "every": ("形容词", "每个"),
        "both": ("代词", "两者"),
        "either": ("代词", "任一"),
        "neither": ("代词", "两者都不"),
        "nothing": ("代词", "没有东西"),
        "something": ("代词", "某物"),
        "anything": ("代词", "任何东西"),
        "everything": ("代词", "一切"),
        "someone": ("代词", "某人"),
        "anyone": ("代词", "任何人"),
        "everyone": ("代词", "每个人"),
        "my": ("代词", "我的"),
        "your": ("代词", "你的"),
        "his": ("代词", "他的"),
        "her": ("代词", "她的"),
        "its": ("代词", "它的"),
        "our": ("代词", "我们的"),
        "their": ("代词", "他们的"),
        "me": ("代词", "我"),
        "you": ("代词", "你"),
        "he": ("代词", "他"),
        "she": ("代词", "她"),
        "it": ("代词", "它"),
        "we": ("代词", "我们"),
        "they": ("代词", "他们"),
        "myself": ("代词", "我自己"),
        "yourself": ("代词", "你自己"),
        "himself": ("代词", "他自己"),
        "herself": ("代词", "她自己"),
        "itself": ("代词", "它自己"),
        "ourselves": ("代词", "我们自己"),
        "themselves": ("代词", "他们自己"),
        "yes": ("感叹词", "是的"),
        "no": ("感叹词", "不"),

        // 科技相关词汇
        "technology": ("名词", "技术"),
        "computer": ("名词", "电脑"),
        "internet": ("名词", "互联网"),
        "software": ("名词", "软件"),
        "hardware": ("名词", "硬件"),
        "data": ("名词", "数据"),
        "network": ("名词", "网络"),
        "security": ("名词", "安全"),
        "privacy": ("名词", "隐私"),
        "algorithm": ("名词", "算法"),
        "application": ("名词", "应用；申请"),
        "developer": ("名词", "开发者"),
        "user": ("名词", "用户"),
        "device": ("名词", "设备"),
        "platform": ("名词", "平台"),
        "feature": ("名词", "功能；特征"),
        "version": ("名词", "版本"),
        "update": ("名词/动词", "更新"),
        "download": ("动词", "下载"),
        "upload": ("动词", "上传"),
        "share": ("动词", "分享"),
        "connect": ("动词", "连接"),
        "search": ("动词", "搜索"),
        "click": ("动词", "点击"),
        "scroll": ("动词", "滚动"),
        "swipe": ("动词", "滑动"),
        "tap": ("动词", "轻触"),
        "type": ("动词", "打字"),
        "save": ("动词", "保存"),
        "delete": ("动词", "删除"),
        "copy": ("动词", "复制"),
        "paste": ("动词", "粘贴"),
        "print": ("动词", "打印"),
        "scan": ("动词", "扫描"),
        "store": ("动词", "存储"),
        "access": ("动词", "访问"),
        "online": ("形容词", "在线的"),
        "offline": ("形容词", "离线的"),
        // digital 已在上方定义
        "virtual": ("形容词", "虚拟的"),
        "automatic": ("形容词", "自动的"),
        "manual": ("形容词", "手动的"),
        "wireless": ("形容词", "无线的"),
        "mobile": ("形容词", "移动的"),
        "smart": ("形容词", "智能的"),
        "advanced": ("形容词", "先进的"),
        "basic": ("形容词", "基础的"),
        "complex": ("形容词", "复杂的"),
        // simple 已在上方定义
        "fast": ("形容词", "快速的"),
        "slow": ("形容词", "慢的"),

        // 新闻相关词汇
        "news": ("名词", "新闻"),
        "report": ("名词/动词", "报告；报道"),
        "article": ("名词", "文章"),
        "headline": ("名词", "标题"),
        // story 已在上方定义
        "journalist": ("名词", "记者"),
        "editor": ("名词", "编辑"),
        "author": ("名词", "作者"),
        "reader": ("名词", "读者"),
        "viewer": ("名词", "观众"),
        "broadcast": ("名词/动词", "广播"),
        "publish": ("动词", "出版；发布"),
        "announce": ("动词", "宣布"),
        "reveal": ("动词", "揭露"),
        "cover": ("动词", "报道；覆盖"),
        "latest": ("形容词", "最新的"),
        "breaking": ("形容词", "突发"),
        // headline 已在上方定义
        "exclusive": ("形容词", "独家"),
        "top": ("形容词", "顶部的；首要的"),
        "major": ("形容词", "主要的"),
        "minor": ("形容词", "次要的"),
        "leading": ("形容词", "领先的"),
        "official": ("形容词", "官方的"),
        "unofficial": ("形容词", "非官方的"),
        "confirmed": ("形容词", "确认的"),
        "unconfirmed": ("形容词", "未确认的"),
        "rumored": ("形容词", "传闻的"),
        "expected": ("形容词", "预期的"),
        "unexpected": ("形容词", "意外的"),

        // 更多新闻常用词汇
        "minister": ("名词", "部长；大臣"),
        "election": ("名词", "选举"),
        "vote": ("名词/动词", "投票"),
        "campaign": ("名词/动词", "运动；竞选"),
        "candidate": ("名词", "候选人"),
        "congress": ("名词", "国会；代表大会"),
        "parliament": ("名词", "议会"),
        "senate": ("名词", "参议院"),
        "bill": ("名词", "法案；账单"),
        "court": ("名词", "法院"),
        "judge": ("名词", "法官"),
        "trial": ("名词", "审判"),
        "crime": ("名词", "犯罪"),
        "police": ("名词", "警察"),
        "investigation": ("名词", "调查"),
        "probe": ("名词/动词", "调查；探查"),
        "inquiry": ("名词", "询问；调查"),
        "arrest": ("名词/动词", "逮捕"),
        "charge": ("名词/动词", "指控；收费"),
        "sentence": ("名词/动词", "判决；句子"),
        "prison": ("名词", "监狱"),
        "jail": ("名词", "监狱"),
        "release": ("名词/动词", "释放；发布"),
        "strike": ("名词/动词", "罢工；打击"),
        "protest": ("名词/动词", "抗议"),
        "demonstration": ("名词", "示威"),
        "march": ("名词/动词", "游行；前进"),
        "rally": ("名词/动词", "集会"),
        "speech": ("名词", "演讲"),
        "statement": ("名词", "声明；陈述"),
        "declaration": ("名词", "宣言；声明"),
        "address": ("名词/动词", "地址；演讲"),
        "meeting": ("名词", "会议"),
        "conference": ("名词", "会议；大会"),
        "summit": ("名词", "峰会；顶点"),
        "talks": ("名词", "会谈"),
        "negotiation": ("名词", "谈判"),
        "agreement": ("名词", "协议"),
        "deal": ("名词", "交易；协议"),
        "treaty": ("名词", "条约"),
        "contract": ("名词", "合同"),
        "sign": ("动词", "签署；签名"),
        "signing": ("名词", "签署"),
        "accord": ("名词", "协议"),
        "pact": ("名词", "公约；协定"),
        "battle": ("名词", "战斗"),
        "conflict": ("名词", "冲突"),
        "crisis": ("名词", "危机"),
        "attack": ("名词/动词", "攻击"),
        "violence": ("名词", "暴力"),
        "peace": ("名词", "和平"),
        " ceasefire": ("名词", "停火"),
        "military": ("名词/形容词", "军队；军事的"),
        "army": ("名词", "军队"),
        "navy": ("名词", "海军"),
        "troops": ("名词", "部队"),
        "soldier": ("名词", "士兵"),
        "weapon": ("名词", "武器"),
        "bomb": ("名词/动词", "炸弹；轰炸"),
        "explosion": ("名词", "爆炸"),
        "blast": ("名词", "爆炸"),
        "fire": ("名词/动词", "火灾；射击；解雇"),
        "shoot": ("动词", "射击"),
        "shooting": ("名词", "枪击事件"),
        "victim": ("名词", "受害者"),
        "survivor": ("名词", "幸存者"),
        "witness": ("名词/动词", "证人；目击"),
        "rescue": ("名词/动词", "救援"),
        "aid": ("名词/动词", "援助"),
        "support": ("名词/动词", "支持"),
        "assist": ("动词", "协助"),
        "donate": ("动词", "捐赠"),
        "donation": ("名词", "捐赠"),
        "fund": ("名词/动词", "资金；资助"),
        "funding": ("名词", "资金"),
        "budget": ("名词", "预算"),
        "cost": ("名词/动词", "成本；花费"),
        "price": ("名词", "价格"),
        "value": ("名词", "价值"),
        "rate": ("名词", "比率；利率"),
        "inflation": ("名词", "通货膨胀"),
        "growth": ("名词", "增长"),
        "economy": ("名词", "经济"),
        "stock": ("名词", "股票"),
        "trade": ("名词/动词", "贸易；交易"),
        "export": ("名词/动词", "出口"),
        "import": ("名词/动词", "进口"),
        "industry": ("名词", "工业；产业"),
        "firm": ("名词", "公司；商行"),
        "corporation": ("名词", "公司；企业"),
        "enterprise": ("名词", "企业"),
        "organization": ("名词", "组织"),
        "institution": ("名词", "机构"),
        "agency": ("名词", "机构；代理"),
        "bank": ("名词", "银行"),
        "investment": ("名词", "投资"),
        "investor": ("名词", "投资者"),
        "profit": ("名词", "利润"),
        "loss": ("名词", "损失"),
        "income": ("名词", "收入"),
        "revenue": ("名词", "收入；税收"),
        "tax": ("名词", "税"),
        "salary": ("名词", "薪水"),
        "wage": ("名词", "工资"),
        "employment": ("名词", "就业"),
        "unemployment": ("名词", "失业"),
        "worker": ("名词", "工人"),
        "employee": ("名词", "雇员"),
        "employer": ("名词", "雇主"),
        "labor": ("名词", "劳动"),
        "union": ("名词", "工会；联盟"),
        "science": ("名词", "科学"),
        "tech": ("名词", "技术"),
        "experiment": ("名词", "实验"),
        "test": ("名词/动词", "测试"),
        "finding": ("名词", "发现"),
        "discovery": ("名词", "发现"),
        "invention": ("名词", "发明"),
        "innovation": ("名词", "创新"),
        "development": ("名词", "发展"),
        "progress": ("名词", "进步"),
        "advance": ("名词/动词", "进展；前进"),
        "breakthrough": ("名词", "突破"),
        "success": ("名词", "成功"),
        "failure": ("名词", "失败"),
        "achievement": ("名词", "成就"),
        "goal": ("名词", "目标"),
        "target": ("名词", "目标"),
        "aim": ("名词/动词", "目标；瞄准"),
        "objective": ("名词", "目标"),
        "purpose": ("名词", "目的"),
        "plan": ("名词/动词", "计划"),
        "strategy": ("名词", "战略"),
        "tactic": ("名词", "策略"),
        "method": ("名词", "方法"),
        "approach": ("名词/动词", "方法；接近"),
        "solution": ("名词", "解决方案"),
        "problem": ("名词", "问题"),
        "challenge": ("名词", "挑战"),
        "difficulty": ("名词", "困难"),
        "trouble": ("名词", "麻烦"),
        "risk": ("名词", "风险"),
        "danger": ("名词", "危险"),
        "threat": ("名词", "威胁"),
        "concern": ("名词/动词", "担忧；关注"),
        "fear": ("名词/动词", "恐惧；担心"),
        "worry": ("名词/动词", "担忧"),
        "anxiety": ("名词", "焦虑"),
        "stress": ("名词", "压力"),
        "pressure": ("名词", "压力"),
        "tension": ("名词", "紧张"),
        "hospital": ("名词", "医院"),
        "doctor": ("名词", "医生"),
        "patient": ("名词", "病人"),
        "treatment": ("名词", "治疗"),
        "medicine": ("名词", "药物；医学"),
        "drug": ("名词", "药物"),
        "vaccine": ("名词", "疫苗"),
        "virus": ("名词", "病毒"),
        "disease": ("名词", "疾病"),
        "illness": ("名词", "疾病"),
        "condition": ("名词", "状况；条件"),
        "symptom": ("名词", "症状"),
        "infection": ("名词", "感染"),
        "pandemic": ("名词", "大流行"),
        "outbreak": ("名词", "爆发"),
        "spread": ("名词/动词", "传播"),
        "measure": ("名词/动词", "措施；测量"),
        "step": ("名词", "步骤；措施"),
        "action": ("名词", "行动"),
        "decision": ("名词", "决定"),
        "choice": ("名词", "选择"),
        "option": ("名词", "选项"),
        "alternative": ("名词/形容词", "替代方案；替代的"),
        "possibility": ("名词", "可能性"),
        "chance": ("名词", "机会；可能性"),
        "opportunity": ("名词", "机会"),
        "hope": ("名词/动词", "希望"),
        "wish": ("名词/动词", "愿望；希望"),
        "desire": ("名词/动词", "渴望"),
        "dream": ("名词/动词", "梦想"),
        "thought": ("名词", "思想"),
        "opinion": ("名词", "意见"),
        "view": ("名词", "观点；看法"),
        "perspective": ("名词", "视角"),
        "attitude": ("名词", "态度"),
        "belief": ("名词", "信念"),
        "faith": ("名词", "信仰"),
        "religion": ("名词", "宗教"),
        "culture": ("名词", "文化"),
        "tradition": ("名词", "传统"),
        "custom": ("名词", "习俗"),
        "habit": ("名词", "习惯"),
        "practice": ("名词/动词", "实践；练习"),
        "behavior": ("名词", "行为"),
        "activity": ("名词", "活动"),
        "event": ("名词", "事件"),
        "incident": ("名词", "事件"),
        "occasion": ("名词", "场合"),
        "situation": ("名词", "情况"),
        "circumstance": ("名词", "情况"),
        "state": ("名词", "状态；国家"),
        "status": ("名词", "地位；状态"),
        "position": ("名词", "位置；职位"),
        "role": ("名词", "角色"),
        "function": ("名词/动词", "功能；运作"),
        "duty": ("名词", "职责"),
        "responsibility": ("名词", "责任"),
        "obligation": ("名词", "义务"),
        "freedom": ("名词", "自由"),
        "liberty": ("名词", "自由"),
        "justice": ("名词", "正义"),
        "equality": ("名词", "平等"),
        "fairness": ("名词", "公平"),
        "rule": ("名词/动词", "规则；统治"),
        "regulation": ("名词", "规章"),
        "restriction": ("名词", "限制"),
        "limit": ("名词/动词", "限制"),
        "control": ("名词/动词", "控制"),
        "authority": ("名词", "权威；当局"),
        "influence": ("名词/动词", "影响"),
        "impact": ("名词/动词", "影响"),
        "effect": ("名词", "效果；影响"),
        "outcome": ("名词", "结果"),
        "consequence": ("名词", "后果"),
        "cause": ("名词/动词", "原因；导致"),
        "factor": ("名词", "因素"),
        "element": ("名词", "要素"),
        "aspect": ("名词", "方面"),
        "characteristic": ("名词", "特征"),
        "quality": ("名词", "质量；品质"),
        "property": ("名词", "财产；属性"),
        "attribute": ("名词", "属性"),
        "nature": ("名词", "性质；自然"),
        "character": ("名词", "性格；角色"),
        "personality": ("名词", "个性"),
        "identity": ("名词", "身份"),
        "background": ("名词", "背景"),
        "past": ("名词/形容词", "过去"),
        "future": ("名词/形容词", "未来"),
        "present": ("名词/形容词", "现在；当前的"),
        "previous": ("形容词", "之前的"),
        "earlier": ("形容词", "较早的"),
        "later": ("形容词/副词", "较晚的"),
        "final": ("形容词", "最终的"),
        "initial": ("形容词", "最初的"),
        "beginning": ("名词", "开始"),
        "start": ("名词/动词", "开始"),
        "finish": ("名词/动词", "完成"),
        "complete": ("形容词/动词", "完整的；完成"),
        "pause": ("名词/动词", "暂停"),
        "halt": ("名词/动词", "停止"),
        "delay": ("名词/动词", "延迟"),
        "anticipate": ("动词", "预期"),
        "predict": ("动词", "预测"),
        "forecast": ("名词/动词", "预测"),
        "estimate": ("名词/动词", "估计"),
        "calculate": ("动词", "计算"),
        "count": ("名词/动词", "计算；数"),
        "assess": ("动词", "评估"),
        "evaluate": ("动词", "评估"),
        "analyze": ("动词", "分析"),
        "examine": ("动词", "检查"),
        "inspect": ("动词", "视察"),
        "review": ("名词/动词", "审查；复习"),
        "check": ("名词/动词", "检查"),
        "verify": ("动词", "核实"),
        "confirm": ("动词", "确认"),
        "prove": ("动词", "证明"),
        "demonstrate": ("动词", "证明；展示"),
        "display": ("名词/动词", "展示"),
        "disclose": ("动词", "披露"),
        "expose": ("动词", "暴露"),
        "uncover": ("动词", "揭露"),
        "discover": ("动词", "发现"),
        "locate": ("动词", "定位"),
        "identify": ("动词", "识别"),
        "recognize": ("动词", "认出"),
        "acknowledge": ("动词", "承认"),
        "admit": ("动词", "承认"),
        "accept": ("动词", "接受"),
        "reject": ("动词", "拒绝"),
        "refuse": ("动词", "拒绝"),
        "deny": ("动词", "否认"),
        "dispute": ("名词/动词", "争议；争论"),
        "argue": ("动词", "争论"),
        "debate": ("名词/动词", "辩论"),
        "discuss": ("动词", "讨论"),
        "talk": ("动词", "谈论"),
        "inform": ("动词", "通知"),
        "notify": ("动词", "通知"),
        "declare": ("动词", "声明"),
        "claim": ("名词/动词", "声称"),
        "assert": ("动词", "断言"),
        "maintain": ("动词", "坚持；维护"),
        "insist": ("动词", "坚持"),
        "demand": ("名词/动词", "要求"),
        "request": ("名词/动词", "请求"),
        "answer": ("名词/动词", "回答"),
        "reply": ("名词/动词", "回复"),
        "respond": ("动词", "回应"),
        "react": ("动词", "反应"),
        "response": ("名词", "回应"),
        "reaction": ("名词", "反应"),
        "comment": ("名词/动词", "评论"),
        "remark": ("名词/动词", "评论"),
        "criticism": ("名词", "批评"),
        "criticize": ("动词", "批评"),
        "praise": ("名词/动词", "赞扬"),
        "approve": ("动词", "批准；赞同"),
        "agree": ("动词", "同意"),
        "disagree": ("动词", "不同意"),
        "oppose": ("动词", "反对"),
        "object": ("动词", "反对"),
        "favor": ("名词/动词", "支持；偏爱"),
        "endorse": ("动词", "支持；认可"),
        "recommend": ("动词", "推荐"),
        "propose": ("动词", "提议"),
        "supply": ("动词", "供应"),
        "grant": ("名词/动词", "授予；拨款"),
        "award": ("名词/动词", "奖项；授予"),
        "receive": ("动词", "收到"),
        "obtain": ("动词", "获得"),
        "acquire": ("动词", "获得"),
        "gain": ("名词/动词", "获得"),
        "earn": ("动词", "赚取"),
        "miss": ("动词", "错过"),
        "fail": ("动词", "失败"),
        "succeed": ("动词", "成功"),
        "achieve": ("动词", "实现"),
        "accomplish": ("动词", "完成"),
        "perform": ("动词", "执行；表演"),
        "execute": ("动词", "执行"),
        "implement": ("动词", "实施"),
        "carry": ("动词", "执行；携带"),
        "conduct": ("名词/动词", "行为；进行"),
        "operate": ("动词", "操作"),
        "manage": ("动词", "管理"),
        "handle": ("动词", "处理"),
        "tackle": ("动词", "处理"),
        "solve": ("动词", "解决"),
        "resolve": ("动词", "解决"),
        "settle": ("动词", "解决；定居"),
        "fix": ("动词", "修理；解决"),
        "repair": ("动词", "修理"),
        "correct": ("动词/形容词", "纠正；正确的"),
        "improve": ("动词", "改进"),
        "enhance": ("动词", "增强"),
        "increase": ("名词/动词", "增加"),
        "expand": ("动词", "扩张"),
        "extend": ("动词", "扩展"),
        "enlarge": ("动词", "扩大"),
        "reduce": ("动词", "减少"),
        "decrease": ("名词/动词", "减少"),
        "lower": ("动词", "降低"),
        "restrict": ("动词", "限制"),
        "regulate": ("动词", "调节"),
        "adjust": ("动词", "调整"),
        "modify": ("动词", "修改"),
        "alter": ("动词", "改变"),
        "transform": ("动词", "转变"),
        "convert": ("动词", "转换"),
        "replace": ("动词", "替换"),
        "substitute": ("动词", "替代"),
        "exchange": ("名词/动词", "交换"),
        "switch": ("名词/动词", "切换"),
        "shift": ("名词/动词", "转移"),
        "transfer": ("名词/动词", "转移"),
        "remove": ("动词", "移除"),
        "cancel": ("动词", "取消"),
        "eliminate": ("动词", "消除"),
        "erase": ("动词", "擦除"),
        "clean": ("动词/形容词", "清洁；干净的"),
        "wash": ("动词", "洗"),
        "dry": ("动词/形容词", "干燥；干的"),
        "wet": ("形容词", "湿的"),
        "warm": ("形容词", "温暖的"),
        "cool": ("形容词", "凉爽的"),
        "fresh": ("形容词", "新鲜的"),
        "stale": ("形容词", "陈旧的"),
        "classic": ("形容词", "经典的"),
        "rare": ("形容词", "稀有的"),
        "unique": ("形容词", "独特的"),
        "ordinary": ("形容词", "普通的"),
        "normal": ("形容词", "正常的"),
        "regular": ("形容词", "定期的；正常的"),
        "standard": ("名词/形容词", "标准；标准的"),
        "typical": ("形容词", "典型的"),
        "average": ("名词/形容词", "平均；一般的"),
        "usual": ("形容词", "通常的"),
        "unusual": ("形容词", "不寻常的"),
        "strange": ("形容词", "奇怪的"),
        "odd": ("形容词", "奇怪的"),
        "weird": ("形容词", "奇怪的"),
        "bizarre": ("形容词", "怪异的"),
        "extraordinary": ("形容词", "非凡的"),
        "remarkable": ("形容词", "显著的"),
        "notable": ("形容词", "值得注意的"),
        "crucial": ("形容词", "关键的"),
        "critical": ("形容词", "关键的"),
        "essential": ("形容词", "必要的"),
        "necessary": ("形容词", "必要的"),
        "required": ("形容词", "要求的"),
        "optional": ("形容词", "可选的"),
        "voluntary": ("形容词", "自愿的"),
        "compulsory": ("形容词", "强制性的"),
        "mandatory": ("形容词", "强制性的"),
        "legal": ("形容词", "合法的"),
        "illegal": ("形容词", "非法的"),
        "lawful": ("形容词", "合法的"),
        "unlawful": ("形容词", "非法的"),
        "valid": ("形容词", "有效的"),
        "invalid": ("形容词", "无效的"),
        "false": ("形容词", "虚假的"),
        "accurate": ("形容词", "准确的"),
        "inaccurate": ("形容词", "不准确的"),
        "incorrect": ("形容词", "不正确的"),
        "wrong": ("形容词", "错误的"),
        "mistaken": ("形容词", "错误的"),
        "proper": ("形容词", "适当的"),
        "appropriate": ("形容词", "适当的"),
        "suitable": ("形容词", "适合的"),
        "fit": ("形容词/动词", "适合的；适应"),
        "irrelevant": ("形容词", "不相关的"),
        "related": ("形容词", "相关的"),
        "connected": ("形容词", "连接的"),
        "linked": ("形容词", "关联的"),
        "associated": ("形容词", "相关的"),
        "similar": ("形容词", "相似的"),
        "identical": ("形容词", "相同的"),
        "unlike": ("形容词", "不同的"),
        "equal": ("形容词", "相等的"),
        "unequal": ("形容词", "不等的"),
        "fair": ("形容词", "公平的"),
        "unfair": ("形容词", "不公平的"),
        " unjust": ("形容词", "不公正的"),
        "honest": ("形容词", "诚实的"),
        "dishonest": ("形容词", "不诚实的"),
        " sincere": ("形容词", "真诚的"),
        "fake": ("形容词", "假的"),
        "actual": ("形容词", "实际的"),
        "genuine": ("形容词", "真正的"),
        "authentic": ("形容词", "真实的"),
        "artificial": ("形容词", "人工的"),
        "synthetic": ("形容词", "合成的"),
        "original": ("形容词", "原始的"),
        "duplicate": ("名词/形容词", "副本；复制的"),
        "primary": ("形容词", "主要的；最初的"),
        "secondary": ("形容词", "次要的"),
        "chief": ("形容词", "主要的"),
        "principal": ("形容词", "主要的"),
        "key": ("形容词", "关键的"),
        "central": ("形容词", "中心的"),
        "core": ("形容词", "核心的"),
        "fundamental": ("形容词", "基本的"),
        "elementary": ("形容词", "基础的"),
        "intermediate": ("形容词", "中级的"),
        "expert": ("名词/形容词", "专家；专业的"),
        "amateur": ("名词/形容词", "业余；业余的"),
        "skilled": ("形容词", "熟练的"),
        "experienced": ("形容词", "有经验的"),
        "inexperienced": ("形容词", "无经验的"),
        "qualified": ("形容词", "合格的"),
        "competent": ("形容词", "有能力的"),
        "capable": ("形容词", "有能力的"),
        "incapable": ("形容词", "无能力的"),
        "unable": ("形容词", "不能的"),
        "impossible": ("形容词", "不可能的"),
        "probable": ("形容词", "可能的"),
        "unlikely": ("形容词", "不太可能的"),
        "likely": ("形容词", "可能的"),
        "certain": ("形容词", "确定的"),
        "uncertain": ("形容词", "不确定的"),
        " unsure": ("形容词", "不确定的"),
        "confident": ("形容词", "有信心的"),
        "doubtful": ("形容词", "怀疑的"),
        "suspicious": ("形容词", "可疑的"),
        "obvious": ("形容词", "明显的"),
        "unclear": ("形容词", "不清楚的"),
        "ambiguous": ("形容词", "模糊的"),
        "vague": ("形容词", "模糊的"),
        "explicit": ("形容词", "明确的"),
        "implicit": ("形容词", "隐含的"),
        "specific": ("形容词", "具体的"),
        "general": ("形容词", "一般的"),
        "broad": ("形容词", "广泛的"),
        "narrow": ("形容词", "狭窄的"),
        "wide": ("形容词", "宽的"),
        "thin": ("形容词", "薄的；瘦的"),
        "thick": ("形容词", "厚的"),
        "fat": ("形容词", "胖的"),
        "slim": ("形容词", "苗条的"),
        "short": ("形容词", "短的；矮的"),
        "tall": ("形容词", "高的"),
        "low": ("形容词", "低的"),
        "deep": ("形容词", "深的"),
        "shallow": ("形容词", "浅的"),
        "heavy": ("形容词", "重的"),
        "light": ("形容词", "轻的"),
        "weak": ("形容词", "弱的"),
        "powerful": ("形容词", "强大的"),
        "soft": ("形容词", "软的"),
        "tough": ("形容词", "艰难的"),
        "complicated": ("形容词", "复杂的"),
        "confusing": ("形容词", "令人困惑的"),
        "evident": ("形容词", "明显的"),
        "apparent": ("形容词", "明显的"),
        "hidden": ("形容词", "隐藏的"),
        "visible": ("形容词", "可见的"),
        "invisible": ("形容词", "不可见的"),
        "private": ("形容词", "私人的"),
        "individual": ("名词/形容词", "个人；个人的"),
        "collective": ("形容词", "集体的"),
        "group": ("名词", "群体"),
        "crowd": ("名词", "人群"),
        "audience": ("名词", "观众"),
        "spectator": ("名词", "观众"),
        "listener": ("名词", "听众"),
        "customer": ("名词", "顾客"),
        "client": ("名词", "客户"),
        "consumer": ("名词", "消费者"),
        "buyer": ("名词", "买家"),
        "seller": ("名词", "卖家"),
        "merchant": ("名词", "商人"),
        "trader": ("名词", "商人"),
        "dealer": ("名词", "商人"),
        "supplier": ("名词", "供应商"),
        "manufacturer": ("名词", "制造商"),
        "producer": ("名词", "生产者"),
        "creator": ("名词", "创造者"),
        "maker": ("名词", "制造者"),
        "builder": ("名词", "建造者"),
        "designer": ("名词", "设计师"),
        "artist": ("名词", "艺术家"),
        "writer": ("名词", "作家"),
        "publisher": ("名词", "出版商"),
        "reporter": ("名词", "记者"),
        "correspondent": ("名词", "通讯员"),
        "broadcaster": ("名词", "广播员"),
        "announcer": ("名词", "播音员"),
        "presenter": ("名词", "主持人"),
        "host": ("名词", "主持人"),
        "guest": ("名词", "嘉宾"),
        "speaker": ("名词", "演讲者"),
        "participant": ("名词", "参与者"),
        "leader": ("名词", "领导者"),
        "follower": ("名词", "追随者"),
        "supporter": ("名词", "支持者"),
        "opponent": ("名词", "对手"),
        "competitor": ("名词", "竞争者"),
        "rival": ("名词", "对手"),
        "enemy": ("名词", "敌人"),
        "ally": ("名词", "盟友"),
        "partner": ("名词", "伙伴"),
        "associate": ("名词", "同事"),
        "colleague": ("名词", "同事"),
        "coworker": ("名词", "同事"),
        "neighbor": ("名词", "邻居"),
        "relative": ("名词", "亲戚"),
        "family": ("名词", "家庭"),
        "mother": ("名词", "母亲"),
        "son": ("名词", "儿子"),
        "daughter": ("名词", "女儿"),
        "brother": ("名词", "兄弟"),
        "sister": ("名词", "姐妹"),
        "husband": ("名词", "丈夫"),
        "wife": ("名词", "妻子"),
        "children": ("名词", "孩子们"),
        "baby": ("名词", "婴儿"),
        "adult": ("名词", "成年人"),
        "woman": ("名词", "女人"),
        "male": ("名词/形容词", "男性；男性的"),
        "female": ("名词/形容词", "女性；女性的"),
        "human": ("名词/形容词", "人；人类的"),
        "being": ("名词", "存在；生物"),
        "creature": ("名词", "生物"),
        "animal": ("名词", "动物"),
        "plant": ("名词", "植物"),
        "thing": ("名词", "东西"),
        "item": ("名词", "物品"),
        "product": ("名词", "产品"),
        "goods": ("名词", "商品"),
        "material": ("名词", "材料"),
        "substance": ("名词", "物质"),
        "matter": ("名词", "物质；事情"),
        "space": ("名词", "空间"),
        "location": ("名词", "位置"),
        "region": ("名词", "地区"),
        "zone": ("名词", "区域"),
        "district": ("名词", "区域"),
        "territory": ("名词", "领土"),
        "country": ("名词", "国家"),
        "nation": ("名词", "国家；民族"),
        "town": ("名词", "城镇"),
        "village": ("名词", "村庄"),
        "capital": ("名词", "首都；资本"),
        "center": ("名词", "中心"),
        "middle": ("名词", "中间"),
        "border": ("名词", "边界"),
        "boundary": ("名词", "边界"),
        "edge": ("名词", "边缘"),
        "corner": ("名词", "角落"),
        "front": ("名词/形容词", "前面；前方的"),
        "bottom": ("名词", "底部"),
        "surface": ("名词", "表面"),
        "layer": ("名词", "层"),
        "floor": ("名词", "地板；楼层"),
        "ground": ("名词", "地面"),
        "ceiling": ("名词", "天花板"),
        "wall": ("名词", "墙壁"),
        "window": ("名词", "窗户"),
        "roof": ("名词", "屋顶"),
        "building": ("名词", "建筑物"),
        "school": ("名词", "学校"),
        "university": ("名词", "大学"),
        "college": ("名词", "学院"),
        "class": ("名词", "班级；课程"),
        "lesson": ("名词", "课"),
        "course": ("名词", "课程"),
        "subject": ("名词", "科目"),
        "topic": ("名词", "话题"),
        "theme": ("名词", "主题"),
        "detail": ("名词", "细节"),
        "knowledge": ("名词", "知识"),
        "wisdom": ("名词", "智慧"),
        "skill": ("名词", "技能"),
        "ability": ("名词", "能力"),
        "talent": ("名词", "才能"),
        "genius": ("名词", "天才"),
        "intelligence": ("名词", "智力"),
        "training": ("名词", "培训"),
        "learning": ("名词", "学习"),
        "teaching": ("名词", "教学"),
        "instruction": ("名词", "指导"),
        "guidance": ("名词", "指导"),
        "direction": ("名词", "方向"),
        "command": ("名词/动词", "命令"),
        "order": ("名词/动词", "命令；顺序"),
        "permission": ("名词", "许可"),
        "approval": ("名词", "批准"),
        "acceptance": ("名词", "接受"),
        "rejection": ("名词", "拒绝"),
        "disagreement": ("名词", "不同意"),
        "consensus": ("名词", "共识"),
        "argument": ("名词", "争论"),
        "quarrel": ("名词/动词", "争吵"),
        "fight": ("名词/动词", "打架；战斗"),
        "struggle": ("名词/动词", "斗争"),
        "clash": ("名词/动词", "冲突"),
        "load": ("名词", "负载"),
        "burden": ("名词", "负担"),
        "weight": ("名词", "重量"),
        "size": ("名词", "大小"),
        "shape": ("名词", "形状"),
        "form": ("名词", "形式"),
        "sort": ("名词", "种类"),
        "category": ("名词", "类别"),
        "collection": ("名词", "集合"),
        "series": ("名词", "系列"),
        "sequence": ("名词", "序列"),
        "arrangement": ("名词", "安排"),
        "structure": ("名词", "结构"),
        "connection": ("名词", "连接"),
        "link": ("名词", "链接"),
        "chain": ("名词", "链条"),
        "cycle": ("名词", "循环"),
        "procedure": ("名词", "程序"),
        "mode": ("名词", "模式"),
        "style": ("名词", "风格"),
        "fashion": ("名词", "时尚"),
        "trend": ("名词", "趋势"),
        "path": ("名词", "路径"),
        "route": ("名词", "路线"),
        "road": ("名词", "道路"),
        "street": ("名词", "街道"),
        "avenue": ("名词", "大道"),
        "lane": ("名词", "小巷"),
        "track": ("名词", "轨道；路径"),
        "trail": ("名词", "痕迹；路径"),
        "journey": ("名词", "旅程"),
        "trip": ("名词", "旅行"),
        "travel": ("名词/动词", "旅行"),
        "voyage": ("名词", "航行"),
        "flight": ("名词", "航班"),
        "ride": ("名词", "乘坐"),
        "drive": ("名词/动词", "驾驶"),
        "jump": ("名词/动词", "跳"),
        "climb": ("名词/动词", "攀登"),
        "rise": ("名词/动词", "上升"),
        "ascend": ("动词", "上升"),
        "descend": ("动词", "下降"),
        "enter": ("动词", "进入"),
        "exit": ("名词/动词", "出口；退出"),
        "arrive": ("动词", "到达"),
        "depart": ("动词", "离开"),
        "return": ("名词/动词", "返回"),
        "proceed": ("动词", "继续"),
        "evolve": ("动词", "进化"),
        "multiply": ("动词", "增加"),
        "diminish": ("动词", "减少"),
        "vanish": ("动词", "消失"),
        "emerge": ("动词", "出现"),
        "disappear": ("动词", "消失"),
        "fade": ("动词", "消失"),
        "hide": ("动词", "隐藏"),
        "open": ("动词", "打开"),
        "close": ("动词", "关闭"),
        "shut": ("动词", "关闭"),
        "lock": ("名词/动词", "锁"),
        "unlock": ("动词", "解锁"),
        "block": ("名词/动词", "阻碍；块"),
        "unblock": ("动词", "解除阻碍"),
        "permit": ("动词", "许可"),
        "prevent": ("动词", "阻止"),
        "avoid": ("动词", "避免"),
        "escape": ("名词/动词", "逃避"),
        "evade": ("动词", "回避"),
        "dodge": ("动词", "躲避"),
        "skip": ("动词", "跳过"),
        "catch": ("动词", "抓住"),
        "grab": ("动词", "抓住"),
        "drop": ("动词", "掉落"),
        "throw": ("动词", "扔"),
        "cast": ("动词", "投掷"),
        "pitch": ("名词/动词", "投掷"),
        "toss": ("动词", "扔"),
        "pick": ("动词", "选择；捡"),
        "choose": ("动词", "选择"),
        "select": ("动词", "选择"),
        "determine": ("动词", "确定"),
        "score": ("名词/动词", "得分"),
        "mark": ("名词/动词", "标记"),
        "label": ("名词/动词", "标签；标注"),
        "tag": ("名词/动词", "标签"),
        "title": ("名词", "标题"),
        "heading": ("名词", "标题"),
        "caption": ("名词", "字幕；标题"),
        "text": ("名词", "文本"),
        "phrase": ("名词", "短语"),
        "paragraph": ("名词", "段落"),
        "chapter": ("名词", "章节"),
        "section": ("名词", "部分"),
        "piece": ("名词", "块；片"),
        "fragment": ("名词", "碎片"),
        "segment": ("名词", "片段"),
        "portion": ("名词", "部分"),
        "fraction": ("名词", "小部分"),
        "bit": ("名词", "小块"),
        "slice": ("名词", "切片"),
        "chip": ("名词", "碎片；芯片"),
        "crumb": ("名词", "碎屑"),
        "particle": ("名词", "粒子"),
        "atom": ("名词", "原子"),
        "molecule": ("名词", "分子"),
        "cell": ("名词", "细胞"),
        "tissue": ("名词", "组织"),
        "organ": ("名词", "器官"),
        "eye": ("名词", "眼睛"),
        "ear": ("名词", "耳朵"),
        "nose": ("名词", "鼻子"),
        "mouth": ("名词", "嘴"),
        "lip": ("名词", "嘴唇"),
        "tongue": ("名词", "舌头"),
        "tooth": ("名词", "牙齿"),
        "teeth": ("名词", "牙齿"),
        "gum": ("名词", "牙龈"),
        "hair": ("名词", "头发"),
        "skin": ("名词", "皮肤"),
        "bone": ("名词", "骨头"),
        "muscle": ("名词", "肌肉"),
        "blood": ("名词", "血液"),
        "heart": ("名词", "心脏"),
        "brain": ("名词", "大脑"),
        "lung": ("名词", "肺"),
        "liver": ("名词", "肝脏"),
        "kidney": ("名词", "肾脏"),
        "stomach": ("名词", "胃"),
        "chest": ("名词", "胸部"),
        "arm": ("名词", "手臂"),
        "finger": ("名词", "手指"),
        "thumb": ("名词", "拇指"),
        "leg": ("名词", "腿"),
        "feet": ("名词", "脚"),
        "toe": ("名词", "脚趾"),
        "nail": ("名词", "指甲"),
        "neck": ("名词", "脖子"),
        "shoulder": ("名词", "肩膀"),
        "knee": ("名词", "膝盖"),
        "elbow": ("名词", "肘"),
        "wrist": ("名词", "手腕"),
        "ankle": ("名词", "脚踝"),
        "hip": ("名词", "臀部"),
        "waist": ("名词", "腰部"),
    ]

    /// 补充高频功能词、代词和情态动词，提升文章阅读查词覆盖率。
    private let supplementalDictionary: [String: (pos: String?, definition: String)] = [
        "the": ("determiner", "这；那；该"),
        "a": ("determiner", "一个；某个"),
        "an": ("determiner", "一个；某个"),
        "as": ("preposition", "作为；像；如同"),
        "and": ("conjunction", "和；并且；而且"),
        "or": ("conjunction", "或者；还是；否则"),
        "but": ("conjunction", "但是；然而"),
        "not": ("adverb", "不；并非"),
        "if": ("conjunction", "如果；是否"),
        "than": ("conjunction", "比；相比"),
        "so": ("adverb", "如此；所以"),
        "because": ("conjunction", "因为"),
        "that": ("determiner", "那个；那；引导从句"),
        "this": ("determiner", "这；这个"),
        "these": ("determiner", "这些"),
        "those": ("determiner", "那些"),
        "what": ("pronoun", "什么；所...的事物"),
        "which": ("pronoun", "哪一个；哪一些"),
        "who": ("pronoun", "谁"),
        "how": ("adverb", "怎样；如何"),
        "i": ("pronoun", "我"),
        "me": ("pronoun", "我"),
        "my": ("determiner", "我的"),
        "mine": ("pronoun", "我的"),
        "you": ("pronoun", "你；你们"),
        "your": ("determiner", "你的；你们的"),
        "he": ("pronoun", "他"),
        "him": ("pronoun", "他"),
        "his": ("determiner", "他的"),
        "she": ("pronoun", "她"),
        "her": ("pronoun", "她；她的"),
        "it": ("pronoun", "它；这件事"),
        "its": ("determiner", "它的"),
        "we": ("pronoun", "我们"),
        "us": ("pronoun", "我们"),
        "our": ("determiner", "我们的"),
        "they": ("pronoun", "他们；她们；它们"),
        "them": ("pronoun", "他们；她们；它们"),
        "their": ("determiner", "他们的；她们的；它们的"),
        "one": ("noun", "一；一个；某人"),
        "two": ("noun", "二；两个"),
        "three": ("noun", "三；三个"),
        "four": ("noun", "四；四个"),
        "some": ("determiner", "一些；某些"),
        "many": ("determiner", "许多的"),
        "much": ("determiner", "许多；大量"),
        "all": ("determiner", "全部；所有"),
        "any": ("determiner", "任何；一些"),
        "another": ("determiner", "另一个；再一个"),
        "each": ("determiner", "每个；各自"),
        "every": ("determiner", "每个；一切"),
        "both": ("determiner", "两者都"),
        "most": ("determiner", "大多数；最"),
        "other": ("determiner", "别的；其他的"),
        "only": ("adjective", "唯一的；仅有的"),
        "same": ("adjective", "相同的"),
        "such": ("determiner", "这样的；如此的"),
        "few": ("determiner", "很少；几个"),
        "more": ("determiner", "更多；更大的"),
        "enough": ("determiner", "足够；充分"),
        "can": ("verb", "能；可以"),
        "could": ("verb", "能够；可能；可以"),
        "may": ("verb", "可以；可能"),
        "might": ("verb", "也许；可能"),
        "will": ("verb", "将会；愿意"),
        "would": ("verb", "将会；会；愿意"),
        "shall": ("verb", "将；应该"),
        "must": ("verb", "必须；一定"),
        "should": ("verb", "应该"),
        "to": ("preposition", "到；向；对于"),
        "of": ("preposition", "的；属于；关于"),
        "for": ("preposition", "为了；对于；给"),
        "from": ("preposition", "从；来自"),
        "in": ("preposition", "在...里；在...中"),
        "on": ("preposition", "在...上；关于"),
        "at": ("preposition", "在；于"),
        "by": ("preposition", "通过；由；在...旁边"),
        "with": ("preposition", "和；与；带有"),
        "about": ("preposition", "关于；大约"),
        "after": ("preposition", "在...之后"),
        "before": ("preposition", "在...之前"),
        "between": ("preposition", "在...之间"),
        "under": ("preposition", "在...下面"),
        "through": ("preposition", "通过；穿过"),
        "without": ("preposition", "没有；不"),
        "until": ("preposition", "直到"),
        "up": ("adverb", "向上；起来"),
        "down": ("adverb", "向下；下降"),
        "out": ("adverb", "出去；外面"),
        "off": ("adverb", "离开；关闭"),
        "over": ("preposition", "在...上方；越过"),
        "into": ("preposition", "进入；到...里面"),
        "now": ("adverb", "现在；此刻"),
        "then": ("adverb", "然后；那时"),
        "there": ("adverb", "那里；那儿"),
        "here": ("adverb", "这里；此处"),
        "when": ("adverb", "何时；当...时"),
        "where": ("adverb", "哪里；在...的地方"),
        "why": ("adverb", "为什么"),
        "too": ("adverb", "也；太"),
        "very": ("adverb", "非常"),
        "just": ("adverb", "刚刚；只是；正好"),
        "even": ("adverb", "甚至；即使"),
        "also": ("adverb", "也；而且"),
        "still": ("adverb", "仍然；依旧"),
        "once": ("adverb", "一次；曾经"),
        "soon": ("adverb", "很快；不久"),
        "away": ("adverb", "离开；远离"),
        "together": ("adverb", "一起；共同"),
        "far": ("adverb", "远；遥远"),
        "well": ("adverb", "好；很好；充分")
    ]

    /// 获取单词的多个中文释义
    func getDefinitions(for word: String) -> [String] {
        let candidates = dictionaryLookupCandidates(for: word)
        var definitions: [String] = []
        var seen = Set<String>()

        for candidate in candidates {
            guard let entry = dictionaryEntry(for: candidate) else { continue }
            for meaning in splitDefinitions(entry.definition) {
                if seen.insert(meaning).inserted {
                    definitions.append(meaning)
                }
            }
        }

        return definitions
    }

    /// 获取单词的中文释义
    func getDefinition(for word: String) -> String? {
        let definitions = getDefinitions(for: word)
        guard !definitions.isEmpty else { return nil }
        return definitions.joined(separator: "；")
    }

    /// 获取单词的词性（从词典）
    func getPartOfSpeechFromDictionary(for word: String) -> String? {
        for candidate in dictionaryLookupCandidates(for: word) {
            if let entry = dictionaryEntry(for: candidate) {
                return normalizedPartOfSpeech(entry.pos)
            }
        }

        return nil
    }

    private func dictionaryEntry(for candidate: String) -> (pos: String?, definition: String)? {
        if let entry = simpleDictionary[candidate] {
            return entry
        }
        return supplementalDictionary[candidate]
    }

    private func dictionaryLookupCandidates(for word: String) -> [String] {
        let normalized = normalizeLookupWord(word)
        guard !normalized.isEmpty else { return [] }

        var candidates: [String] = [normalized]
        var seen = Set(candidates)

        func appendCandidate(_ candidate: String?) {
            guard let candidate, !candidate.isEmpty else { return }
            if seen.insert(candidate).inserted {
                candidates.append(candidate)
            }
        }

        appendCandidate(getLemma(for: normalized)?.lowercased())

        if let irregulars = irregularWordForms[normalized] {
            for irregular in irregulars {
                appendCandidate(irregular)
            }
        }

        for derived in deriveBaseForms(from: normalized) {
            appendCandidate(derived)
        }

        return candidates
    }

    private func normalizeLookupWord(_ word: String) -> String {
        var normalized = word.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")

        normalized = normalized.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))

        if normalized.hasSuffix("'s") {
            normalized.removeLast(2)
        } else if normalized.hasSuffix("s'") {
            normalized.removeLast()
        }

        if normalized.hasSuffix("n't") {
            switch normalized {
            case "can't":
                normalized = "can"
            case "won't":
                normalized = "will"
            case "shan't":
                normalized = "shall"
            default:
                normalized = String(normalized.dropLast(3))
            }
        } else if normalized.hasSuffix("'re") || normalized.hasSuffix("'ve") || normalized.hasSuffix("'ll") {
            normalized.removeLast(3)
        } else if normalized.hasSuffix("'d") || normalized.hasSuffix("'m") {
            normalized.removeLast(2)
        }

        return normalized
    }

    private func deriveBaseForms(from word: String) -> [String] {
        var forms: [String] = []

        if word.count > 4 && word.hasSuffix("ies") {
            forms.append(String(word.dropLast(3)) + "y")
        }

        if word.count > 4 && word.hasSuffix("ves") {
            forms.append(String(word.dropLast(3)) + "f")
            forms.append(String(word.dropLast(3)) + "fe")
        }

        if word.count > 3 && word.hasSuffix("es") {
            forms.append(String(word.dropLast(2)))
        }

        if word.count > 3 && word.hasSuffix("s") {
            forms.append(String(word.dropLast()))
        }

        if word.count > 5 && word.hasSuffix("ing") {
            let stem = String(word.dropLast(3))
            forms.append(stem)
            forms.append(stem + "e")
            if stem.count > 2, let last = stem.last {
                let chars = Array(stem)
                if chars.count >= 2, chars[chars.count - 1] == chars[chars.count - 2] {
                    forms.append(String(stem.dropLast()))
                }
                if last == "y" {
                    forms.append(String(stem.dropLast()) + "ie")
                }
            }
        }

        if word.count > 4 && word.hasSuffix("ied") {
            forms.append(String(word.dropLast(3)) + "y")
        }

        if word.count > 3 && word.hasSuffix("ed") {
            let stem = String(word.dropLast(2))
            forms.append(stem)
            forms.append(stem + "e")
            let chars = Array(stem)
            if chars.count >= 2, chars[chars.count - 1] == chars[chars.count - 2] {
                forms.append(String(stem.dropLast()))
            }
        }

        if word.count > 4 && word.hasSuffix("er") {
            forms.append(String(word.dropLast(2)))
            forms.append(String(word.dropLast(2)) + "e")
        }

        if word.count > 5 && word.hasSuffix("est") {
            forms.append(String(word.dropLast(3)))
            forms.append(String(word.dropLast(3)) + "e")
        }

        if word.count > 4 && word.hasSuffix("ly") {
            forms.append(String(word.dropLast(2)))
        }

        return Array(Set(forms.filter { !$0.isEmpty && $0 != word }))
    }

    private func splitDefinitions(_ definition: String) -> [String] {
        let normalized = definition
            .replacingOccurrences(of: "、", with: "；")
            .replacingOccurrences(of: ";", with: "；")
            .replacingOccurrences(of: "|", with: "；")

        return normalized
            .components(separatedBy: "；")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizedPartOfSpeech(_ pos: String?) -> String? {
        guard let pos else { return nil }

        switch pos {
        case "名词": return "noun"
        case "动词": return "verb"
        case "形容词": return "adjective"
        case "副词": return "adverb"
        case "代词": return "pronoun"
        case "介词": return "preposition"
        case "连词": return "conjunction"
        case "限定词": return "determiner"
        case "感叹词": return "interjection"
        default:
            if pos.contains("名词") { return "noun" }
            if pos.contains("动词") { return "verb" }
            if pos.contains("形容词") { return "adjective" }
            if pos.contains("副词") { return "adverb" }
            if pos.contains("代词") { return "pronoun" }
            if pos.contains("介词") { return "preposition" }
            if pos.contains("连词") { return "conjunction" }
            if pos.contains("限定词") { return "determiner" }
            if pos.contains("感叹词") { return "interjection" }
            return pos
        }
    }

    // MARK: - 系统词典

    /// 检查系统词典是否有某单词的定义
    func hasSystemDefinition(for word: String, language: String = "en") -> Bool {
        return UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
    }

    /// 使用系统词典查询单词（返回UIViewController供展示）
    func systemDictionaryViewController(for word: String) -> UIViewController {
        return UIReferenceLibraryViewController(term: word)
    }

    // MARK: - NLP 分析

    /// 使用NaturalLanguage框架分析文本
    func analyzeText(_ text: String) -> TextAnalysis {
        let analyzer = TextAnalyzer(text: text)
        return analyzer.analyze()
    }

    /// 获取单词的词性
    func getPartOfSpeech(for word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = word

        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lexicalClass)
        return tag?.rawValue
    }

    /// 获取单词的词元形式（原形）
    func getLemma(for word: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word

        let (tag, _) = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma)
        return tag?.rawValue
    }

    /// 对文本进行词性标注
    func tagText(_ text: String) -> [TokenTag] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        var tokens: [TokenTag] = []

        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { substring, range, _, _ in
            guard let substring = substring else { return }

            let (lexicalTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
            let (lemmaTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma)

            let token = TokenTag(
                text: substring,
                range: NSRange(range, in: text),
                partOfSpeech: lexicalTag?.rawValue,
                lemma: lemmaTag?.rawValue
            )
            tokens.append(token)
        }

        return tokens
    }

    /// 识别句子边界
    func detectSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            sentences.append(sentence)
            return true
        }

        return sentences
    }

    /// 识别单词边界
    func detectWords(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            words.append(word)
            return true
        }

        return words
    }
}

// MARK: - 文本分析结果

struct TextAnalysis {
    var sentences: [SentenceAnalysis]
    var totalWords: Int
    var uniqueWords: Set<String>
    var unknownWords: Set<String>

    init() {
        self.sentences = []
        self.totalWords = 0
        self.uniqueWords = []
        self.unknownWords = []
    }
}

struct SentenceAnalysis {
    var text: String
    var tokens: [TokenTag]
}

struct TokenTag {
    var text: String
    var range: NSRange
    var partOfSpeech: String?
    var lemma: String?

    var displayName: String {
        if let pos = partOfSpeech {
            return "\(text) (\(pos))"
        }
        return text
    }
}

// MARK: - 文本分析器

class TextAnalyzer {
    private let text: String

    init(text: String) {
        self.text = text
    }

    func analyze() -> TextAnalysis {
        var analysis = TextAnalysis()

        // 识别句子
        let sentences = DictionaryService.shared.detectSentences(text)

        for sentence in sentences {
            let tokens = DictionaryService.shared.tagText(sentence)
            let sentenceAnalysis = SentenceAnalysis(text: sentence, tokens: tokens)
            analysis.sentences.append(sentenceAnalysis)
        }

        // 统计单词
        let words = DictionaryService.shared.detectWords(text)
        analysis.totalWords = words.count

        // 获取唯一单词（词元形式）
        for word in words {
            if let lemma = DictionaryService.shared.getLemma(for: word) {
                analysis.uniqueWords.insert(lemma.lowercased())
            } else {
                analysis.uniqueWords.insert(word.lowercased())
            }
        }

        return analysis
    }

    /// 提取生词（基于已知词汇表）
    func extractUnknownWords(knownWords: Set<String>) -> Set<String> {
        let words = DictionaryService.shared.detectWords(text)
        var unknown = Set<String>()

        for word in words {
            let lowercased = word.lowercased()
            if let lemma = DictionaryService.shared.getLemma(for: word) {
                let lemmaLowercased = lemma.lowercased()
                if !knownWords.contains(lemmaLowercased) {
                    unknown.insert(lemmaLowercased)
                }
            } else if !knownWords.contains(lowercased) {
                unknown.insert(lowercased)
            }
        }

        return unknown
    }
}

// MARK: - 词性颜色映射

extension DictionaryService {
    /// 根据词性获取高亮颜色
    static func colorForPartOfSpeech(_ pos: String?) -> String {
        guard let pos = pos else { return "#000000" }

        switch pos {
        case "noun":
            return "#E57373" // 红色
        case "verb":
            return "#81C784" // 绿色
        case "adjective":
            return "#64B5F6" // 蓝色
        case "adverb":
            return "#FFD54F" // 黄色
        case "pronoun":
            return "#BA68C8" // 紫色
        case "preposition":
            return "#A1887F" // 棕色
        case "conjunction":
            return "#90A4AE" // 灰色
        case "determiner":
            return "#4DB6AC" // 青色
        case "interjection":
            return "#FF8A65" // 橙色
        default:
            return "#000000"
        }
    }

    /// 词性中文描述
    static func displayNameForPartOfSpeech(_ pos: String?) -> String {
        guard let pos = pos else { return "未知" }

        switch pos {
        case "noun":
            return "名词"
        case "verb":
            return "动词"
        case "adjective":
            return "形容词"
        case "adverb":
            return "副词"
        case "pronoun":
            return "代词"
        case "preposition":
            return "介词"
        case "conjunction":
            return "连词"
        case "determiner":
            return "限定词"
        case "interjection":
            return "感叹词"
        default:
            return "其他"
        }
    }
}

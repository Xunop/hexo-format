import hanlp

sentences = ""
with open("tmp.txt", "r", encoding="utf-8") as f:
    for line in f:
        sentences += line.strip()

HanLp = hanlp.pipeline() \
        .append(hanlp.utils.rules.split_sentence) \
        .append(hanlp.load('FINE_ELECTRA_SMALL_ZH'), output_key='tok')

results = HanLp('计算机网络学习笔记，参考《计算机网络-自顶向下方法》。 这章内容涉及许多层，相当于一个大的概括，之后才会解析每个层次的内容。')
print(results)

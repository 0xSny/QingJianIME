清简输入法采用 GPL-3.0 发布。发行包的对应源代码由同一仓库的发行标签提供。

词库编译自 [雾凇拼音](https://github.com/iDvel/rime-ice) 的 8105 与 base 字典，保留上游 GPL-3.0 许可。原始数据及其中列明的作者见 tools/dictionary.py 固定的上游提交。构建时过滤并转换为二进制音节前缀树。

上下文统计取自 [UD Chinese GSDSimp](https://github.com/UniversalDependencies/UD_Chinese-GSDSimp)，按 CC BY-SA 4.0 许可提供。构建阶段将分词结果转换为相邻词频数表，该派生表沿用原许可。

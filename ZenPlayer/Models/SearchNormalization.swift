import Foundation

/// 首版固定检索字表；只用于比较，不改原标题。表外异体字保持原样。
nonisolated enum SearchNormalization {
    private static let simplified: [Character: Character] = {
        let pairs = "無无 壽寿 經经 淨净 彌弥 說说 講讲 學学 習习 觀观 會会 眾众 寶宝 莊庄 嚴严 華华 蓮莲 國国 門门 體体 禮礼 懺忏 願愿 顯显 識识 覺觉 圓圆 滿满 導导 師师 傳传 統统 總总 綱纲 領领 選选 頌颂 讚赞 歎叹 勸劝 讀读 誦诵 釋释 論论 註注 記记 錄录 啟启 發发 髮发 頭头 後后 來来 萬万 與与 為为 過过 時时 間间 長长 開开 關关 順顺 緣缘 隨随 轉转 業业 報报 應应 實实 義义 歸归 處处 樂乐 離离 難难 雙双 聞闻 聲声 靜静 親亲 愛爱 廣广 題题 編编 號号 聽听 復复 複复 書书 虛虚 稱称 專专 羅罗 龍龙 護护 結结 證证 獨独 達达 儀仪 養养 賢贤 聖圣 話话 問问 遺遗 補补 譯译 風风 見见 網网 絡络 電电 腦脑 畫画 圖图 廟庙 燈灯 禪禅 孫孙 趙赵 趨趋 執执 殺杀 斷断 滅灭 續续 種种 遠远 區区 誠诚 請请 機机 範范 囑嘱 懷怀 諸诸 際际 規规 節节 練练"
        var table: [Character: Character] = [:]
        for pair in pairs.split(separator: " ") {
            let characters = Array(pair)
            table[characters[0]] = characters[1]
        }
        return table
    }()

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(folded.map { simplified[$0] ?? $0 })
    }
}

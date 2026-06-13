import Foundation

/// 表格族 — table / thead / tbody / tfoot / tr / th / td（含真实复杂场景）
enum TableExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "table-basic", title: "简单数据表", summary: "thead + tbody 常规行列",
            html: """
            <table><thead><tr><th>姓名</th><th>部门</th><th>入职</th></tr></thead>
            <tbody><tr><td>张三</td><td>工程</td><td>2021</td></tr>
            <tr><td>李四</td><td>设计</td><td>2022</td></tr>
            <tr><td>王五</td><td>产品</td><td>2020</td></tr></tbody></table>
            """,
            family: .table, tier: .basic),
        DemoExample(id: "table-layout", title: "编程语言对比", summary: "<table> + <tr> + <td> + <th>",
            html: """
            <h3>编程语言对比</h3>
            <table>
            <tr><th>语言</th><th>类型</th><th>特点</th></tr>
            <tr><td>Swift</td><td>编译型</td><td>安全、快速、现代</td></tr>
            <tr><td>Kotlin</td><td>编译型</td><td>简洁、互操作性强</td></tr>
            <tr><td>Python</td><td>解释型</td><td>简单易学、生态丰富</td></tr>
            <tr><td>Rust</td><td>编译型</td><td>零成本抽象、内存安全</td></tr>
            </table>
            """,
            family: .table, tier: .nested),
        DemoExample(id: "table-finance", title: "季度财务报表", summary: "跨列表头分组 + tfoot 汇总行",
            html: """
            <table><thead><tr><th rowspan="2">项目</th><th colspan="2">2025 Q1</th><th colspan="2">2025 Q2</th></tr>
            <tr><th>收入</th><th>支出</th><th>收入</th><th>支出</th></tr></thead>
            <tbody><tr><td>主营业务</td><td>1,200</td><td>800</td><td>1,500</td><td>780</td></tr>
            <tr><td>其他业务</td><td>200</td><td>120</td><td>240</td><td>110</td></tr></tbody>
            <tfoot><tr><td>合计</td><td>1,400</td><td>920</td><td>1,740</td><td>890</td></tr></tfoot></table>
            """,
            family: .table, tier: .nested,
            note: "验证 colspan/rowspan 表头分组 + tfoot 汇总"),
        DemoExample(id: "table-product-compare", title: "产品参数对比", summary: "多列属性 + ✓/✗ 高亮",
            html: """
            <table><thead><tr><th>特性</th><th>基础版</th><th>专业版</th><th>旗舰版</th></tr></thead>
            <tbody><tr><td>存储空间</td><td>5GB</td><td>50GB</td><td><b>无限</b></td></tr>
            <tr><td>团队协作</td><td>✗</td><td>✓</td><td>✓</td></tr>
            <tr><td>优先支持</td><td>✗</td><td>✗</td><td><span style="color:#FF0000">✓</span></td></tr>
            <tr><td>价格/月</td><td>¥0</td><td>¥29</td><td>¥99</td></tr></tbody></table>
            """,
            family: .table, tier: .nested),
        DemoExample(id: "table-schedule", title: "课程表", summary: "跨行 rowspan，时间 × 星期矩阵",
            html: """
            <table><thead><tr><th>时间</th><th>周一</th><th>周二</th><th>周三</th><th>周四</th><th>周五</th></tr></thead>
            <tbody><tr><td rowspan="2">上午</td><td>语文</td><td>数学</td><td>英语</td><td>物理</td><td>化学</td></tr>
            <tr><td>数学</td><td>语文</td><td>物理</td><td>英语</td><td>生物</td></tr>
            <tr><td>下午</td><td>体育</td><td>音乐</td><td>美术</td><td>历史</td><td>地理</td></tr></tbody></table>
            """,
            family: .table, tier: .nested,
            note: "验证 rowspan 跨行合并"),
        DemoExample(id: "table-nested-list", title: "含嵌套列表的单元格", summary: "td 内 <ul><li>",
            html: """
            <table><thead><tr><th>产品</th><th>特性列表</th></tr></thead>
            <tbody><tr><td>XMarkup</td><td><ul><li>HTML 解析</li><li>富文本渲染</li><li>主题系统</li></ul></td></tr>
            <tr><td>竞品 A</td><td><ul><li>仅解析</li></ul></td></tr></tbody></table>
            """,
            family: .table, tier: .nested,
            note: "验证单元格内块级嵌套（td 内 ul/li）"),
        DemoExample(id: "table-styled-cell", title: "带样式高亮的表格", summary: "td 内 <span style> 高亮异常值",
            html: """
            <table><thead><tr><th>指标</th><th>本月</th><th>环比</th></tr></thead>
            <tbody><tr><td>DAU</td><td>1,250,000</td><td><span style="color:#00AA00">+12.5%</span></td></tr>
            <tr><td>崩溃率</td><td>0.8%</td><td><span style="color:#FF0000"><b>+0.3%</b></span></td></tr></tbody></table>
            """,
            family: .table, tier: .nested),
        DemoExample(id: "table-edge", title: "表格边界", summary: "空单元格 / 缺 thead",
            html: """
            <table><tr><td>有值</td><td></td></tr><tr><td></td><td>有值</td></tr></table>
            """,
            family: .table, tier: .boundary, isRegression: true,
            note: "验证空单元格容错"),
    ]
}

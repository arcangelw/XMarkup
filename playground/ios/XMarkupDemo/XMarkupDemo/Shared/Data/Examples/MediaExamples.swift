import Foundation

/// 媒体族 — img / video / audio / source / figure
enum MediaExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "image-single", title: "单张图片", summary: "<img src=\"...\"> 标签",
            html: """
            <h3>富士山日出</h3>
            <p><img src="https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?w=600"></p>
            <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
            """,
            family: .media, tier: .basic),
        DemoExample(id: "video-single", title: "视频", summary: "<video src=\"...\"> 标签",
            html: """
            <h3>🎥 Big Buck Bunny 片段</h3>
            <p><video src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"></video></p>
            <p>这是一段开源动画短片，常用于视频播放器测试。</p>
            """,
            family: .media, tier: .basic),
        DemoExample(id: "audio-single", title: "音频", summary: "<audio src=\"...\"> 标签",
            html: """
            <h3>🎵 示例音频</h3>
            <p><audio src="https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"></audio></p>
            <p>SoundHelix 提供的免费示例音乐，适合测试音频渲染占位符。</p>
            """,
            family: .media, tier: .basic),
        DemoExample(id: "video-source", title: "视频（source 子标签）", summary: "<video><source src type>",
            html: """
            <h3>🎬 Elephant's Dream</h3>
            <video><source src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4" type="video/mp4"></video>
            <p>开源动画项目 <i>Elephant's Dream</i>，由 Blender 基金会制作。</p>
            """,
            family: .media, tier: .nested),
        DemoExample(id: "media-mix", title: "图文音视频混排", summary: "img + video + audio + 文字组合",
            html: """
            <h2>2026 年度旅行 Vlog</h2>
            <p>这次旅行从<b>东京</b>出发，途径 <i>京都</i>、<i>大阪</i>，最终抵达<b>北海道</b>。以下是精彩瞬间 🎬</p>
            <h3>📷 富士山全景</h3>
            <p><img src="https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?w=600"></p>
            <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
            <h3>🎥 街头风景</h3>
            <p><video src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"></video></p>
            <p>城市街头的光影变幻，视频比照片更能传达那种宁静感。</p>
            <h3>🎵 街头艺人演奏</h3>
            <p><audio src="https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"></audio></p>
            <p>在<b>心斋桥</b>遇到的街头艺人，<span style="color:#9B59B6">萨克斯</span>吹得真好听。</p>
            <p>—— 全程使用 iPhone 拍摄，<a href="https://www.apple.com/iphone/">拍摄器材清单</a></p>
            """,
            family: .media, tier: .nested),
    ]
}

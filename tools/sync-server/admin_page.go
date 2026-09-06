package main

// 管理端单页应用:侧边栏分区(概览/用户/图书库/活动日志/系统),无外部依赖。
// 注意:Go raw string 内不能出现反引号,JS 一律使用字符串拼接而非模板字面量。
const adminPageHTML = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Omni Reader · 同步服务器管理</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Crect width='24' height='24' rx='6' fill='%234c6ef5'/%3E%3Cpath d='M6 5h3.5a3 3 0 0 1 3 3v11a2.5 2.5 0 0 0-2.5-2.5H6z' fill='white'/%3E%3Cpath d='M18 5h-3.5a3 3 0 0 0-3 3' fill='none' stroke='white' stroke-width='1.6'/%3E%3C/svg%3E">
<style>
  :root {
    color-scheme: light dark;
    --bg: #f2f4f8; --card: #ffffff; --text: #1d2330; --muted: #697386;
    --line: #e4e8f0; --accent: #4c6ef5; --accent-soft: #edf2ff;
    --ok: #0f9960; --ok-soft: #e6f7ef; --warn: #e8590c; --warn-soft: #fff0e5;
    --danger: #e03131; --danger-soft: #fdecec; --purple: #7048e8; --purple-soft: #f1ecfd;
    --shadow: 0 1px 2px rgba(16,24,40,.05), 0 1px 3px rgba(16,24,40,.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #14161b; --card: #1e2128; --text: #e6e9f0; --muted: #8b93a7;
      --line: #2b2f3a; --accent: #748ffc; --accent-soft: #262c47;
      --ok-soft: #17352a; --warn-soft: #3a2a1c; --danger-soft: #3a2224; --purple-soft: #2c2444;
      --shadow: none;
    }
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; }
  body {
    margin: 0; display: flex; min-height: 100vh;
    font-family: system-ui, -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
    background: var(--bg); color: var(--text); font-size: 14px;
  }
  a { color: var(--accent); text-decoration: none; }

  /* ---- 登录 ---- */
  .login-wrap { flex: 1; display: flex; align-items: center; justify-content: center; padding: 24px; }
  .login-card { width: 360px; max-width: 100%; background: var(--card); border: 1px solid var(--line);
    border-radius: 16px; padding: 32px 28px; box-shadow: var(--shadow); text-align: center; }
  .login-mark { width: 52px; height: 52px; border-radius: 14px; background: linear-gradient(135deg, #4c6ef5, #22b8cf);
    display: inline-flex; align-items: center; justify-content: center; color: #fff; margin-bottom: 14px; }
  .login-card h1 { font-size: 18px; margin: 0 0 4px; }
  .login-card p { margin: 0 0 18px; color: var(--muted); font-size: 13px; }
  .login-card input { width: 100%; margin-bottom: 12px; }
  .login-card .btn { width: 100%; }

  /* ---- 侧边栏 ---- */
  .sidebar { width: 224px; flex: none; background: #171c2c; color: #aab1c7;
    display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh; }
  .brand { display: flex; align-items: center; gap: 10px; padding: 20px 18px 18px; }
  .brand-mark { width: 36px; height: 36px; border-radius: 10px; flex: none;
    background: linear-gradient(135deg, #4c6ef5, #22b8cf); display: flex; align-items: center; justify-content: center; color: #fff; }
  .brand-name { font-weight: 700; color: #fff; font-size: 15px; line-height: 1.2; }
  .brand-sub { font-size: 11px; color: #6d7690; }
  .nav { flex: 1; padding: 6px 12px; overflow-y: auto; }
  .nav-item { display: flex; align-items: center; gap: 10px; padding: 10px 12px; margin: 2px 0;
    border-radius: 10px; color: #aab1c7; cursor: pointer; font-size: 13.5px; user-select: none; }
  .nav-item:hover { background: rgba(255,255,255,.05); color: #e6e9f0; }
  .nav-item.active { background: rgba(116,143,252,.16); color: #fff; }
  .nav-item svg { width: 17px; height: 17px; flex: none; }
  .side-foot { padding: 14px 18px; border-top: 1px solid rgba(255,255,255,.07); font-size: 12px; }
  .side-ver { color: #6d7690; display: block; margin-bottom: 8px; }
  .side-foot button { background: rgba(255,255,255,.06); color: #aab1c7; border: 0; border-radius: 8px;
    padding: 7px 12px; font-size: 12.5px; cursor: pointer; width: 100%; }
  .side-foot button:hover { background: rgba(255,255,255,.12); color: #fff; }

  /* ---- 主区 ---- */
  .main { flex: 1; min-width: 0; padding: 22px 26px 60px; max-width: 1180px; }
  .topbar { display: flex; align-items: flex-end; gap: 14px; margin-bottom: 18px; }
  .top-title { font-size: 21px; font-weight: 700; margin: 0; }
  .top-sub { color: var(--muted); font-size: 12.5px; margin: 0 0 2px; }
  .top-actions { margin-left: auto; display: flex; gap: 8px; align-items: center; }
  .page { display: none; }
  .page.active { display: block; }
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-top: 14px; }
  .grid-2 > .card { margin: 0; }
  @media (max-width: 960px) { .grid-2 { grid-template-columns: 1fr; } }

  .card { background: var(--card); border: 1px solid var(--line); border-radius: 14px;
    padding: 18px; margin-bottom: 14px; box-shadow: var(--shadow); }
  .card-title { font-size: 14px; font-weight: 700; margin: 0 0 12px; }
  .card-head { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
  .card-head .card-title { margin: 0; }

  .stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
  @media (max-width: 960px) { .stat-grid { grid-template-columns: repeat(2, 1fr); } }
  .stat-card { background: var(--card); border: 1px solid var(--line); border-radius: 14px;
    padding: 16px; box-shadow: var(--shadow); display: flex; gap: 12px; align-items: flex-start; }
  .stat-ico { width: 38px; height: 38px; border-radius: 11px; background: var(--accent-soft);
    color: var(--accent); display: flex; align-items: center; justify-content: center; flex: none; }
  .stat-ico svg { width: 19px; height: 19px; }
  .stat-val { font-size: 23px; font-weight: 700; line-height: 1.15; }
  .stat-label { color: var(--muted); font-size: 12px; }
  .stat-sub { color: var(--muted); font-size: 11.5px; margin-top: 3px; }

  .chips { display: flex; flex-wrap: wrap; gap: 8px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; background: var(--accent-soft);
    color: var(--text); border-radius: 999px; padding: 4px 11px; font-size: 12px; }
  .chip b { font-weight: 600; }

  .bar-row { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; font-size: 13px; }
  .bar-name { width: 92px; flex: none; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .bar-track { flex: 1; height: 8px; border-radius: 999px; background: var(--line); overflow: hidden; }
  .bar-fill { height: 100%; border-radius: 999px; background: linear-gradient(90deg, var(--accent), #22b8cf); }
  .bar-val { width: 76px; flex: none; text-align: right; color: var(--muted); font-size: 12px; }

  .store-bar { display: flex; height: 12px; border-radius: 999px; overflow: hidden;
    background: var(--line); margin: 12px 0 8px; }
  .store-bar > div { height: 100%; }
  .seg-vault { background: linear-gradient(90deg, var(--accent), #22b8cf); }
  .seg-db { background: #f59f00; }
  .legend { display: flex; gap: 16px; font-size: 12px; color: var(--muted); }
  .legend i { display: inline-block; width: 9px; height: 9px; border-radius: 3px; margin-right: 5px; }

  .tbl-wrap { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
  th { text-align: left; padding: 8px 10px; color: var(--muted); font-weight: 600;
    font-size: 11.5px; letter-spacing: .04em; white-space: nowrap; border-bottom: 1px solid var(--line); }
  td { padding: 9px 10px; border-bottom: 1px solid var(--line); vertical-align: middle; }
  tr:last-child td { border-bottom: 0; }
  tbody tr:hover { background: rgba(116,143,252,.05); }

  .badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 2px 9px;
    font-size: 11.5px; font-weight: 600; white-space: nowrap; }
  .b-blue { background: var(--accent-soft); color: var(--accent); }
  .b-green { background: var(--ok-soft); color: var(--ok); }
  .b-red { background: var(--danger-soft); color: var(--danger); }
  .b-orange { background: var(--warn-soft); color: var(--warn); }
  .b-purple { background: var(--purple-soft); color: var(--purple); }
  .b-gray { background: var(--line); color: var(--muted); }

  .btn { padding: 8px 14px; border: 0; border-radius: 9px; font-size: 13.5px; cursor: pointer;
    background: var(--accent); color: #fff; white-space: nowrap; }
  .btn:hover { filter: brightness(1.08); }
  .btn.ghost { background: transparent; color: var(--text); border: 1px solid var(--line); }
  .btn.ghost:hover { background: var(--accent-soft); filter: none; }
  .btn.danger { background: transparent; color: var(--danger); border: 1px solid var(--danger); }
  .btn.danger:hover { background: var(--danger-soft); filter: none; }
  .btn.sm { padding: 4px 10px; font-size: 12px; border-radius: 7px; }
  .btn:disabled { opacity: .5; cursor: default; }
  .btn-row { display: flex; gap: 6px; flex-wrap: wrap; }

  input[type=text], input[type=password] { padding: 8px 11px; border: 1px solid var(--line);
    border-radius: 9px; font-size: 13.5px; background: var(--card); color: var(--text); }
  input[type=text]:focus, input[type=password]:focus { outline: 2px solid var(--accent-soft); border-color: var(--accent); }
  .check { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; color: var(--muted); cursor: pointer; }
  .row { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  .spacer { flex: 1; }
  .muted { color: var(--muted); font-size: 12px; }

  .token-code { background: var(--accent-soft); color: var(--accent); padding: 2px 7px;
    border-radius: 6px; font-size: 12px; cursor: pointer; word-break: break-all; }
  .name-cell b { display: block; white-space: nowrap; }
  .name-cell .muted { font-size: 11.5px; }

  .cover { width: 34px; height: 46px; object-fit: cover; border-radius: 6px;
    border: 1px solid var(--line); display: block; }
  .cover-ph { width: 34px; height: 46px; border-radius: 6px; border: 1px dashed var(--line);
    display: flex; align-items: center; justify-content: center; color: var(--muted); font-size: 12px; }

  .empty { text-align: center; color: var(--muted); padding: 26px 0; font-size: 13px; }

  .act-detail { color: var(--muted); font-size: 12.5px; }
  .act-time { white-space: nowrap; font-size: 12.5px; color: var(--muted); }

  .progress { height: 8px; border-radius: 999px; background: var(--line); overflow: hidden; margin-top: 10px; display: none; }
  .progress > div { height: 100%; width: 0; background: var(--accent); transition: width .2s; }

  .toast { position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%);
    background: #23283a; color: #fff; padding: 10px 18px; border-radius: 10px; font-size: 13px;
    opacity: 0; pointer-events: none; transition: opacity .25s; z-index: 60; max-width: 80vw; }
  .toast.show { opacity: .96; }
  .toast.err { background: #b02a2a; }

  dialog { border: 0; border-radius: 16px; padding: 20px; width: 620px; max-width: 94vw;
    max-height: 86vh; background: var(--card); color: var(--text); box-shadow: 0 20px 60px rgba(0,0,0,.25); }
  dialog::backdrop { background: rgba(10,14,25,.45); }
  dialog h3 { margin: 0 0 4px; font-size: 16px; }
  dialog .dlg-sub { margin: 0 0 14px; }
  dialog .dlg-foot { display: flex; justify-content: flex-end; margin-top: 16px; }
  .dlg-scroll { max-height: 52vh; overflow: auto; }

  @media (max-width: 820px) {
    #appView { flex-direction: column; }
    .sidebar { width: 100%; height: auto; position: static; flex-direction: row; align-items: center; padding: 8px 12px; gap: 8px; }
    .brand { padding: 4px 8px; }
    .brand-sub { display: none; }
    .nav { display: flex; padding: 0; overflow-x: auto; flex: 1; }
    .nav-item { padding: 8px 10px; white-space: nowrap; }
    .nav-item span { display: none; }
    .side-foot { border-top: 0; padding: 0; }
    .side-ver { display: none; }
    .side-foot button { width: auto; }
    .main { padding: 16px 14px 50px; }
  }
</style>
</head>
<body>

<div id="loginView" class="login-wrap" style="display:none">
  <div class="login-card">
    <div class="login-mark">
      <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
    </div>
    <h1>Omni Reader 同步服务器</h1>
    <p>请输入管理员密码进入控制台</p>
    <input type="password" id="password" placeholder="管理员密码" autocomplete="current-password">
    <button class="btn" id="loginBtn">登 录</button>
    <div id="loginMsg" class="muted" style="margin-top:10px;min-height:16px"></div>
  </div>
</div>

<div id="appView" style="display:none;flex:1;min-width:0">
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">
        <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
      </div>
      <div>
        <div class="brand-name">Omni Reader</div>
        <div class="brand-sub">同步服务器控制台</div>
      </div>
    </div>
    <nav class="nav" id="nav">
      <div class="nav-item" data-page="overview"><span class="nav-ico"></span><span>概览</span></div>
      <div class="nav-item" data-page="users"><span class="nav-ico"></span><span>用户管理</span></div>
      <div class="nav-item" data-page="books"><span class="nav-ico"></span><span>图书库</span></div>
      <div class="nav-item" data-page="activity"><span class="nav-ico"></span><span>活动日志</span></div>
      <div class="nav-item" data-page="system"><span class="nav-ico"></span><span>系统</span></div>
    </nav>
    <div class="side-foot">
      <span class="side-ver" id="sideVer">v?</span>
      <button id="logoutBtn">退出登录</button>
    </div>
  </aside>

  <main class="main">
    <div class="topbar">
      <div>
        <h2 class="top-title" id="pageTitle">概览</h2>
        <p class="top-sub" id="pageSub"></p>
      </div>
      <div class="top-actions">
        <button class="btn ghost sm" id="refreshBtn">刷新</button>
      </div>
    </div>

    <!-- 概览 -->
    <section class="page" id="page-overview">
      <div class="stat-grid" id="statCards"></div>
      <div class="grid-2">
        <div class="card">
          <div class="card-title">运行状态</div>
          <div class="chips" id="runtimeChips"></div>
          <div class="store-bar" id="storeBar"></div>
          <div class="legend">
            <span><i class="seg-vault"></i>书文件 <b id="legVault"></b></span>
            <span><i class="seg-db"></i>数据库 <b id="legDb"></b></span>
          </div>
        </div>
        <div class="card">
          <div class="card-title">用户存储占用</div>
          <div id="userBars"></div>
        </div>
      </div>
      <div class="grid-2">
        <div class="card">
          <div class="card-title">最大的书</div>
          <div class="tbl-wrap"><table><tbody id="topBooks"></tbody></table></div>
        </div>
        <div class="card">
          <div class="card-head">
            <div class="card-title">最近动态</div>
            <span class="spacer"></span><a href="#/activity" class="muted">全部 →</a>
          </div>
          <div id="recentActivity"></div>
        </div>
      </div>
    </section>

    <!-- 用户管理 -->
    <section class="page" id="page-users">
      <div class="card">
        <div class="row">
          <input type="text" id="newName" placeholder="新用户名称,如:内测-张三" style="width:230px">
          <button class="btn" id="createBtn">生成 Token</button>
          <span class="spacer"></span>
          <input type="text" id="userSearch" placeholder="搜索用户…" style="width:180px">
        </div>
      </div>
      <div class="card">
        <div class="tbl-wrap">
          <table>
            <thead><tr>
              <th>用户</th><th>Token</th><th>书目</th><th>设备</th><th>占用</th>
              <th>创建时间</th><th>最近活跃</th><th>状态</th><th>操作</th>
            </tr></thead>
            <tbody id="userRows"></tbody>
          </table>
        </div>
        <div class="muted" style="margin-top:10px">删除用户会同时清除其全部同步数据与云端书文件,不可恢复;禁用后该用户 token 立即失效。</div>
      </div>
    </section>

    <!-- 图书库 -->
    <section class="page" id="page-books">
      <div class="card">
        <div class="row">
          <input type="text" id="bookSearch" placeholder="搜索书名 / 用户 / UID…" style="width:260px">
          <label class="check"><input type="checkbox" id="showDeleted"> 显示已删除</label>
          <span class="spacer"></span>
          <span class="muted" id="bookCount"></span>
        </div>
      </div>
      <div class="card">
        <div class="tbl-wrap">
          <table>
            <thead><tr>
              <th></th><th>书名 / 作者</th><th>所属用户</th><th>格式</th><th>大小</th>
              <th>导入时间</th><th>更新时间</th><th>状态</th><th>操作</th>
            </tr></thead>
            <tbody id="bookRows"></tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- 活动日志 -->
    <section class="page" id="page-activity">
      <div class="card">
        <div class="row">
          <label class="check"><input type="checkbox" id="actAuto" checked> 自动刷新(10 秒)</label>
          <span class="spacer"></span>
          <button class="btn ghost sm" id="clearAct">清空记录</button>
        </div>
        <div class="muted" style="margin-top:8px">活动记录保存在内存中(最新 <span id="actCap">400</span> 条),服务重启后清空。</div>
      </div>
      <div class="card">
        <div class="tbl-wrap">
          <table>
            <thead><tr><th>时间</th><th>类型</th><th>用户</th><th>详情</th></tr></thead>
            <tbody id="actRows"></tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- 系统 -->
    <section class="page" id="page-system">
      <div class="grid-2">
        <div class="card">
          <div class="card-title">服务器信息</div>
          <div class="chips" id="sysChips"></div>
        </div>
        <div class="card">
          <div class="card-title">版本与更新</div>
          <div class="row" style="margin-bottom:12px">
            <span style="font-size:20px;font-weight:700" id="sysVersion"></span>
            <span class="badge b-green" id="sysUpdateBadge" style="display:none">热更新版本运行中</span>
          </div>
          <div class="muted" style="margin-bottom:10px">上传 linux/amd64 的 sync-server 二进制,校验(ELF)通过后自动替换重启;新版本写入数据卷,跨容器重启持久。以后升级不再需要重新部署镜像。</div>
          <div class="row">
            <input type="file" id="updateFile">
            <button class="btn" id="updateBtn">上传并重启</button>
            <button class="btn danger" id="rollbackBtn">回滚到镜像版本</button>
          </div>
          <div class="progress" id="updateProgress"><div></div></div>
        </div>
      </div>
      <div class="card">
        <div class="card-title">存储维护</div>
        <div class="row" style="align-items:flex-start;margin-bottom:14px">
          <div style="flex:1;min-width:240px">
            <b style="font-size:13.5px">清理孤儿书目录</b>
            <div class="muted" style="margin-top:3px">删除书库中不再对应任何在架书目的目录(上传中目录有 1 小时宽限),释放磁盘空间。</div>
          </div>
          <button class="btn ghost" id="cleanupBtn">立即清理</button>
        </div>
        <div class="row" style="align-items:flex-start">
          <div style="flex:1;min-width:240px">
            <b style="font-size:13.5px">压缩数据库</b>
            <div class="muted" style="margin-top:3px">执行 SQLite VACUUM,回收删除数据后的空洞。变更日志较大时效果明显。</div>
          </div>
          <button class="btn ghost" id="vacuumBtn">执行 VACUUM</button>
        </div>
        <div class="muted" id="maintResult" style="margin-top:12px;min-height:16px"></div>
      </div>
    </section>
  </main>
</div>

<dialog id="booksDialog">
  <h3 id="booksTitle">图书</h3>
  <p class="muted dlg-sub">云端书单与文件;删除会下墓碑并清空文件,该用户设备下次同步时收敛。</p>
  <div class="dlg-scroll">
    <table style="width:100%">
      <thead><tr><th></th><th>书名</th><th>大小</th><th>更新时间</th><th>状态</th><th>操作</th></tr></thead>
      <tbody id="booksRows"></tbody>
    </table>
  </div>
  <div class="dlg-foot"><button class="btn ghost" id="booksClose">关闭</button></div>
</dialog>

<dialog id="devicesDialog">
  <h3 id="devicesTitle">设备</h3>
  <p class="muted dlg-sub">该用户登录过的阅读设备;移除后设备下次同步会重新注册。</p>
  <div class="dlg-scroll">
    <table style="width:100%">
      <thead><tr><th>设备 ID</th><th>同步书目</th><th>最近活跃</th><th>操作</th></tr></thead>
      <tbody id="devicesRows"></tbody>
    </table>
  </div>
  <div class="dlg-foot"><button class="btn ghost" id="devicesClose">关闭</button></div>
</dialog>

<dialog id="tokenDialog">
  <h3>Token</h3>
  <p class="muted dlg-sub">请立即复制并分发给用户;关闭后仍可在用户列表点击复制。</p>
  <code class="token-code" id="newToken" style="display:inline-block;max-width:100%"></code>
  <div class="dlg-foot">
    <button class="btn" id="copyToken">复制</button>
    <button class="btn ghost" id="tokenClose">关闭</button>
  </div>
</dialog>

<div class="toast" id="toast"></div>

<script>
  var ICONS = {
    overview: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/></svg>',
    users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    books: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
    activity: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
    system: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.08a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h.08a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.08a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
    disk: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/></svg>',
    pulse: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>'
  };
  var ACT_META = {
    'sync.push':           { label: '进度推送', cls: 'b-blue' },
    'sync.pull':           { label: '进度拉取', cls: 'b-blue' },
    'library.announce':    { label: '书目上报', cls: 'b-green' },
    'library.upload':      { label: '书上传', cls: 'b-green' },
    'library.download':    { label: '书取回', cls: 'b-green' },
    'library.delete':      { label: '删除云端书', cls: 'b-red' },
    'admin.login':         { label: '管理员登录', cls: 'b-gray' },
    'admin.user.create':   { label: '创建用户', cls: 'b-orange' },
    'admin.user.delete':   { label: '删除用户', cls: 'b-red' },
    'admin.user.rename':   { label: '用户改名', cls: 'b-orange' },
    'admin.user.enable':   { label: '启用用户', cls: 'b-orange' },
    'admin.user.disable':  { label: '禁用用户', cls: 'b-red' },
    'admin.user.token':    { label: '重置Token', cls: 'b-orange' },
    'admin.book.delete':   { label: '删云端书', cls: 'b-red' },
    'admin.device.delete': { label: '移除设备', cls: 'b-orange' },
    'admin.maintenance':   { label: '存储维护', cls: 'b-purple' },
    'admin.update':        { label: '热更新', cls: 'b-purple' }
  };

  var state = { page: 'overview', usersCache: null, booksCache: null, pollTimer: null };
  var PAGES = {
    overview: { title: '概览', sub: '服务器运行与同步概况', load: loadOverview },
    users:    { title: '用户管理', sub: '生成 token、控制访问、查看每个用户的用量', load: loadUsersPage },
    books:    { title: '图书库', sub: '全部用户的云端书文件', load: loadBooksPage },
    activity: { title: '活动日志', sub: '同步与管理的实时动态', load: loadActivityPage },
    system:   { title: '系统', sub: '运行信息、热更新与存储维护', load: loadSystemPage }
  };

  function $(id) { return document.getElementById(id); }
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtBytes(n) {
    n = Number(n) || 0;
    if (n < 1024) return n + ' B';
    if (n < 1048576) return (n / 1024).toFixed(1) + ' KB';
    if (n < 1073741824) return (n / 1048576).toFixed(1) + ' MB';
    return (n / 1073741824).toFixed(2) + ' GB';
  }
  function pad(n) { return String(n).padStart(2, '0'); }
  function fmtTime(ms) {
    if (!ms) return '—';
    var d = new Date(ms);
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' +
      pad(d.getHours()) + ':' + pad(d.getMinutes());
  }
  function fmtClock(ms) {
    var d = new Date(ms);
    return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }
  function fmtAgo(ms) {
    if (!ms) return '从未';
    var s = Math.floor((Date.now() - ms) / 1000);
    if (s < 60) return '刚刚';
    if (s < 3600) return Math.floor(s / 60) + ' 分钟前';
    if (s < 86400) return Math.floor(s / 3600) + ' 小时前';
    if (s < 86400 * 30) return Math.floor(s / 86400) + ' 天前';
    return fmtTime(ms);
  }
  function fmtUptime(startedAt) {
    var s = Math.floor(Date.now() / 1000 - startedAt / 1000);
    if (s < 3600) return Math.max(1, Math.floor(s / 60)) + ' 分钟';
    if (s < 86400) return Math.floor(s / 3600) + ' 小时';
    return Math.floor(s / 86400) + ' 天 ' + Math.floor(s % 86400 / 3600) + ' 小时';
  }
  var toastTimer = null;
  function toast(text, isError) {
    var el = $('toast');
    el.textContent = text;
    el.className = 'toast show' + (isError ? ' err' : '');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { el.className = 'toast' + (isError ? ' err' : ''); }, 3200);
  }
  function copyText(text, tip) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { toast(tip || '已复制'); });
    } else {
      var input = document.createElement('textarea');
      input.value = text; document.body.appendChild(input); input.select();
      document.execCommand('copy'); document.body.removeChild(input); toast(tip || '已复制');
    }
  }
  function api(method, url, body) {
    var opts = { method: method, headers: {}, credentials: 'same-origin' };
    if (body !== undefined) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    return fetch(url, opts).then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (data) {
        if (!res.ok) { throw new Error(data.error || ('HTTP ' + res.status)); }
        return data;
      });
    });
  }

  // ---- 路由 ----
  function navTo(page) {
    if (location.hash === '#/' + page) { onHash(); }
    else { location.hash = '#/' + page; }
  }
  function onHash() {
    var page = (location.hash || '').replace(/^#\//, '') || 'overview';
    if (!PAGES[page]) page = 'overview';
    state.page = page;
    $('pageTitle').textContent = PAGES[page].title;
    $('pageSub').textContent = PAGES[page].sub;
    var items = document.querySelectorAll('.nav-item');
    Array.prototype.forEach.call(items, function (el) {
      el.className = 'nav-item' + (el.getAttribute('data-page') === page ? ' active' : '');
    });
    Array.prototype.forEach.call(document.querySelectorAll('.page'), function (el) {
      el.className = 'page' + (el.id === 'page-' + page ? ' active' : '');
    });
    setupPoll();
    PAGES[page].load().catch(handleLoadError);
  }
  function setupPoll() {
    if (state.pollTimer) { clearInterval(state.pollTimer); state.pollTimer = null; }
    if (state.page === 'overview') {
      state.pollTimer = setInterval(function () {
        if (document.visibilityState === 'visible') PAGES.overview.load().catch(function () {});
      }, 15000);
    } else if (state.page === 'activity' && $('actAuto').checked) {
      state.pollTimer = setInterval(function () {
        if (document.visibilityState === 'visible') PAGES.activity.load().catch(function () {});
      }, 10000);
    }
  }
  function handleLoadError(err) {
    if (err.message === 'admin login required') { showLogin(); return; }
    toast(err.message, true);
  }

  // ---- 登录 ----
  function showLogin() {
    if (state.pollTimer) { clearInterval(state.pollTimer); state.pollTimer = null; }
    $('appView').style.display = 'none';
    $('loginView').style.display = 'flex';
  }
  function enterApp() {
    $('loginView').style.display = 'none';
    $('appView').style.display = 'flex';
    onHash();
  }
  $('loginBtn').onclick = function () {
    api('POST', '/admin/api/login', { password: $('password').value }).then(function () {
      $('password').value = ''; $('loginMsg').textContent = '';
      enterApp();
    }).catch(function (err) {
      $('loginMsg').textContent = err.message === 'wrong password' ? '密码错误' : err.message;
    });
  };
  $('password').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') $('loginBtn').click();
  });
  $('logoutBtn').onclick = function () {
    api('POST', '/admin/api/logout').then(function () { showLogin(); });
  };
  $('refreshBtn').onclick = function () {
    PAGES[state.page].load().catch(handleLoadError);
  };

  // ---- 概览 ----
  function statCard(icon, label, value, sub) {
    return '<div class="stat-card"><div class="stat-ico">' + icon + '</div><div>' +
      '<div class="stat-val">' + value + '</div>' +
      '<div class="stat-label">' + label + '</div>' +
      '<div class="stat-sub">' + sub + '</div></div></div>';
  }
  function chip(label, value) {
    return '<span class="chip">' + label + ' <b>' + value + '</b></span>';
  }
  function loadOverview() {
    return api('GET', '/admin/api/overview').then(function (d) {
      var t = d.totals, r = d.runtime, today = d.today;
      var todayTotal = today.push + today.pull + today.upload + today.download;
      $('statCards').innerHTML =
        statCard(ICONS.users, '用户', t.users, '启用 ' + t.enabledUsers + ' · 禁用 ' + (t.users - t.enabledUsers)) +
        statCard(ICONS.books, '云端图书', t.books, '墓碑记录 ' + t.deletedBooks) +
        statCard(ICONS.disk, '书文件存储', fmtBytes(t.vaultBytes), '数据库 ' + fmtBytes(t.dbBytes)) +
        statCard(ICONS.pulse, '今日动态', todayTotal, '推送 ' + today.push + ' · 上传 ' + today.upload + ' · 取回 ' + today.download);
      $('sideVer').textContent = 'v' + r.version;
      $('runtimeChips').innerHTML =
        chip('版本', r.version) +
        chip('已运行', fmtUptime(r.startedAt)) +
        chip('平台', r.os + '/' + r.arch) +
        chip('Go', r.goVersion) +
        chip('进度记录', t.progressItems) +
        chip('变更日志', t.changeLog) +
        chip('设备', t.devices) +
        chip('协程', r.goroutines) +
        chip('内存', fmtBytes(r.heapAlloc)) +
        (r.updateReady ? chip('热更新', '已生效') : '');
      var total = t.vaultBytes + t.dbBytes;
      var vaultPct = total > 0 ? Math.max(2, Math.round(t.vaultBytes / total * 100)) : 2;
      var dbPct = total > 0 ? Math.max(2, Math.round(t.dbBytes / total * 100)) : 2;
      if (vaultPct + dbPct > 100) { dbPct = 100 - vaultPct; }
      $('storeBar').innerHTML =
        '<div class="seg-vault" style="width:' + vaultPct + '%"></div>' +
        '<div class="seg-db" style="width:' + dbPct + '%"></div>';
      $('legVault').textContent = fmtBytes(t.vaultBytes);
      $('legDb').textContent = fmtBytes(t.dbBytes);
      renderUserBars(d.perUser || []);
      renderTopBooks(d.topBooks || []);
      renderActivityList($('recentActivity'), (d.recentActivity || []).slice(0, 8), true);
    });
  }
  function renderUserBars(users) {
    var list = users.slice().sort(function (a, b) { return b.vaultBytes - a.vaultBytes; }).slice(0, 8);
    var max = 0;
    list.forEach(function (u) { if (u.vaultBytes > max) max = u.vaultBytes; });
    if (!list.length) { $('userBars').innerHTML = '<div class="empty">还没有用户</div>'; return; }
    var html = '';
    list.forEach(function (u) {
      var pct = max > 0 ? Math.round(u.vaultBytes / max * 100) : 0;
      html += '<div class="bar-row">' +
        '<span class="bar-name" title="' + escapeHtml(u.name) + '">' + escapeHtml(u.name) + '</span>' +
        '<div class="bar-track"><div class="bar-fill" style="width:' + pct + '%"></div></div>' +
        '<span class="bar-val">' + fmtBytes(u.vaultBytes) + ' · ' + u.books + ' 本</span></div>';
    });
    $('userBars').innerHTML = html;
  }
  function renderTopBooks(books) {
    if (!books.length) { $('topBooks').innerHTML = '<tr><td class="empty">还没有云端图书</td></tr>'; return; }
    var html = '';
    books.forEach(function (b) {
      html += '<tr><td>' + escapeHtml(b.title || b.bookUid) +
        '<div class="muted">' + escapeHtml(b.userName) + '</div></td>' +
        '<td style="text-align:right;white-space:nowrap">' + fmtBytes(b.sizeBytes) + '</td></tr>';
    });
    $('topBooks').innerHTML = html;
  }

  // ---- 用户管理 ----
  function loadUsersPage() {
    return api('GET', '/admin/api/users').then(function (d) {
      state.usersCache = d.users || [];
      renderUsers();
    });
  }
  function renderUsers() {
    var term = ($('userSearch').value || '').trim().toLowerCase();
    var list = state.usersCache.filter(function (u) {
      if (!term) return true;
      return u.name.toLowerCase().indexOf(term) >= 0 || String(u.id) === term || u.token.indexOf(term) >= 0;
    });
    if (!list.length) {
      $('userRows').innerHTML = '<tr><td colspan="9" class="empty">' +
        (term ? '没有匹配的用户' : '暂无用户,先在上方生成一个 Token。') + '</td></tr>';
      return;
    }
    var html = '';
    list.forEach(function (u) {
      var masked = u.token.slice(0, 6) + '…' + u.token.slice(-4);
      html += '<tr>' +
        '<td class="name-cell"><b>' + escapeHtml(u.name) + '</b><span class="muted">ID ' + u.id + '</span></td>' +
        '<td><code class="token-code" data-copy="' + u.token + '" title="点击复制完整 token">' + masked + '</code></td>' +
        '<td>' + u.books + '</td>' +
        '<td>' + u.devices + '</td>' +
        '<td>' + fmtBytes(u.vaultBytes) + '</td>' +
        '<td>' + fmtTime(u.createdAt) + '</td>' +
        '<td>' + fmtAgo(u.lastSeenAt) + '</td>' +
        '<td>' + (u.enabled ? '<span class="badge b-green">启用</span>' : '<span class="badge b-red">禁用</span>') + '</td>' +
        '<td><div class="btn-row">' +
          '<button class="btn ghost sm" data-act="books" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">图书</button>' +
          '<button class="btn ghost sm" data-act="devices" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">设备</button>' +
          '<button class="btn ghost sm" data-act="reset" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">重置Token</button>' +
          (u.enabled
            ? '<button class="btn ghost sm" data-act="disable" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">禁用</button>'
            : '<button class="btn ghost sm" data-act="enable" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">启用</button>') +
          '<button class="btn danger sm" data-act="delete" data-id="' + u.id + '" data-name="' + escapeHtml(u.name) + '">删除</button>' +
        '</div></td></tr>';
    });
    $('userRows').innerHTML = html;
    Array.prototype.forEach.call(document.querySelectorAll('#userRows [data-act]'), function (btn) {
      btn.onclick = function () { userAction(btn.getAttribute('data-act'), btn.getAttribute('data-id'), btn.getAttribute('data-name')); };
    });
    Array.prototype.forEach.call(document.querySelectorAll('#userRows [data-copy]'), function (el) {
      el.onclick = function () { copyText(el.getAttribute('data-copy'), 'Token 已复制'); };
    });
  }
  function userAction(act, id, name) {
    if (act === 'books') { showBooks(id, name); return; }
    if (act === 'devices') { showDevices(id, name); return; }
    if (act === 'reset') {
      if (!confirm('重置「' + name + '」的 token?旧 token 将立即失效,需要重新分发。')) return;
      api('POST', '/admin/api/users/' + id + '/token').then(function (d) {
        $('newToken').textContent = d.token;
        $('tokenDialog').showModal();
        loadUsersPage();
      }).catch(function (err) { toast(err.message, true); });
      return;
    }
    if (act === 'disable' || act === 'enable') {
      var enabling = act === 'enable';
      if (!confirm((enabling ? '启用' : '禁用') + '用户「' + name + '」?')) return;
      api('PATCH', '/admin/api/users/' + id, { enabled: enabling }).then(function () {
        toast((enabling ? '已启用 ' : '已禁用 ') + name);
        loadUsersPage();
      }).catch(function (err) { toast(err.message, true); });
      return;
    }
    if (act === 'delete') {
      if (!confirm('确定删除用户「' + name + '」?该用户全部数据与云端书文件将被清除,不可恢复。')) return;
      api('DELETE', '/admin/api/users/' + id).then(function () {
        toast('已删除用户 ' + name);
        loadUsersPage();
      }).catch(function (err) { toast(err.message, true); });
    }
  }
  $('createBtn').onclick = function () {
    var name = $('newName').value.trim();
    if (!name) { toast('请先填写用户名称', true); return; }
    api('POST', '/admin/api/users', { name: name }).then(function (u) {
      $('newName').value = '';
      $('newToken').textContent = u.token;
      $('tokenDialog').showModal();
      loadUsersPage();
    }).catch(function (err) { toast(err.message, true); });
  };
  $('userSearch').oninput = renderUsers;
  $('copyToken').onclick = function () { copyText($('newToken').textContent, 'Token 已复制'); };
  $('tokenClose').onclick = function () { $('tokenDialog').close(); };

  // ---- 用户图书弹窗 ----
  function showBooks(uid, name) {
    $('booksTitle').textContent = '图书 · ' + name;
    api('GET', '/admin/api/users/' + uid + '/books').then(function (d) {
      var books = d.books || [];
      var html = '';
      books.forEach(function (b) {
        var cover = b.coverExt
          ? '<img class="cover" src="/admin/api/users/' + uid + '/books/' + b.bookUid + '/cover" onerror="this.outerHTML=\'<div class=cover-ph>无</div>\'">'
          : '<div class="cover-ph">无</div>';
        html += '<tr><td>' + cover + '</td>' +
          '<td>' + escapeHtml(b.title || b.bookUid) + '</td>' +
          '<td>' + fmtBytes(b.sizeBytes) + '</td>' +
          '<td>' + fmtTime(b.updatedAt) + '</td>' +
          '<td>' + (b.deleted ? '<span class="badge b-red">已删除</span>' : '<span class="badge b-green">正常</span>') + '</td>' +
          '<td>' + (b.deleted ? '' : '<button class="btn danger sm" data-book="' + b.bookUid + '">删除</button>') + '</td></tr>';
      });
      $('booksRows').innerHTML = html || '<tr><td colspan="6" class="empty">该用户还没有云端图书</td></tr>';
      Array.prototype.forEach.call(document.querySelectorAll('#booksRows [data-book]'), function (btn) {
        btn.onclick = function () {
          if (!confirm('确定删除该用户的这本书?')) return;
          api('DELETE', '/admin/api/users/' + uid + '/books/' + btn.getAttribute('data-book'))
            .then(function () { toast('已删除'); showBooks(uid, name); })
            .catch(function (err) { toast(err.message, true); });
        };
      });
      $('booksDialog').showModal();
    }).catch(function (err) { toast(err.message, true); });
  }
  $('booksClose').onclick = function () { $('booksDialog').close(); };

  // ---- 用户设备弹窗 ----
  function showDevices(uid, name) {
    $('devicesTitle').textContent = '设备 · ' + name;
    api('GET', '/admin/api/users/' + uid + '/devices').then(function (d) {
      var devices = d.devices || [];
      var html = '';
      devices.forEach(function (dev) {
        html += '<tr>' +
          '<td><code class="token-code" data-copy="' + escapeHtml(dev.deviceId) + '">' + escapeHtml(dev.deviceId) + '</code></td>' +
          '<td>' + dev.booksSynced + '</td>' +
          '<td>' + fmtAgo(dev.lastSeenAt) + '</td>' +
          '<td><button class="btn danger sm" data-dev="' + escapeHtml(dev.deviceId) + '">移除</button></td></tr>';
      });
      $('devicesRows').innerHTML = html || '<tr><td colspan="4" class="empty">该用户还没有设备记录</td></tr>';
      Array.prototype.forEach.call(document.querySelectorAll('#devicesRows [data-copy]'), function (el) {
        el.onclick = function () { copyText(el.getAttribute('data-copy'), '设备 ID 已复制'); };
      });
      Array.prototype.forEach.call(document.querySelectorAll('#devicesRows [data-dev]'), function (btn) {
        btn.onclick = function () {
          if (!confirm('移除设备 ' + btn.getAttribute('data-dev') + '?')) return;
          api('DELETE', '/admin/api/users/' + uid + '/devices/' + encodeURIComponent(btn.getAttribute('data-dev')))
            .then(function () { toast('已移除'); showDevices(uid, name); })
            .catch(function (err) { toast(err.message, true); });
        };
      });
      $('devicesDialog').showModal();
    }).catch(function (err) { toast(err.message, true); });
  }
  $('devicesClose').onclick = function () { $('devicesDialog').close(); };

  // ---- 图书库 ----
  function loadBooksPage() {
    var includeDeleted = $('showDeleted').checked ? '1' : '0';
    return api('GET', '/admin/api/books?includeDeleted=' + includeDeleted + '&limit=500').then(function (d) {
      state.booksCache = d.books || [];
      renderBooks();
    });
  }
  function renderBooks() {
    var term = ($('bookSearch').value || '').trim().toLowerCase();
    var list = state.booksCache.filter(function (b) {
      if (!term) return true;
      return (b.title || '').toLowerCase().indexOf(term) >= 0 ||
             (b.userName || '').toLowerCase().indexOf(term) >= 0 ||
             b.bookUid.indexOf(term) >= 0;
    });
    $('bookCount').textContent = '共 ' + list.length + ' 本';
    if (!list.length) {
      $('bookRows').innerHTML = '<tr><td colspan="9" class="empty">' +
        (term ? '没有匹配的图书' : '还没有云端图书,客户端导入并备份后出现在这里。') + '</td></tr>';
      return;
    }
    var html = '';
    list.forEach(function (b) {
      var cover = b.coverExt
        ? '<img class="cover" src="/admin/api/users/' + b.userId + '/books/' + b.bookUid + '/cover" onerror="this.outerHTML=\'<div class=cover-ph>无</div>\'">'
        : '<div class="cover-ph">无</div>';
      html += '<tr>' +
        '<td>' + cover + '</td>' +
        '<td><b>' + escapeHtml(b.title || b.bookUid) + '</b>' +
          (b.authors && b.authors.length ? '<div class="muted">' + escapeHtml(b.authors.join(' / ')) + '</div>' : '') + '</td>' +
        '<td>' + escapeHtml(b.userName) + '</td>' +
        '<td>' + escapeHtml(b.format || '—') + '</td>' +
        '<td>' + fmtBytes(b.sizeBytes) + '</td>' +
        '<td>' + fmtTime(b.importedAt) + '</td>' +
        '<td>' + fmtTime(b.updatedAt) + '</td>' +
        '<td>' + (b.deleted ? '<span class="badge b-red">已删除</span>' : '<span class="badge b-green">正常</span>') + '</td>' +
        '<td>' + (b.deleted ? '' : '<button class="btn danger sm" data-delbook="' + b.bookUid + '" data-deluser="' + b.userId + '" data-name="' + escapeHtml(b.title || b.bookUid) + '">删除</button>') + '</td>' +
        '</tr>';
    });
    $('bookRows').innerHTML = html;
    Array.prototype.forEach.call(document.querySelectorAll('#bookRows [data-delbook]'), function (btn) {
      btn.onclick = function () {
        if (!confirm('删除「' + btn.getAttribute('data-name') + '」的云端副本?')) return;
        api('DELETE', '/admin/api/users/' + btn.getAttribute('data-deluser') + '/books/' + btn.getAttribute('data-delbook'))
          .then(function () { toast('已删除'); loadBooksPage(); })
          .catch(function (err) { toast(err.message, true); });
      };
    });
  }
  $('bookSearch').oninput = renderBooks;
  $('showDeleted').onchange = function () { loadBooksPage(); };

  // ---- 活动日志 ----
  function actBadge(type) {
    var meta = ACT_META[type] || { label: type, cls: 'b-gray' };
    return '<span class="badge ' + meta.cls + '">' + meta.label + '</span>';
  }
  function renderActivityList(el, events, compact) {
    if (!events.length) {
      el.innerHTML = '<div class="empty">暂无记录</div>';
      return;
    }
    var html = '<div class="tbl-wrap"><table><tbody>';
    events.forEach(function (e) {
      html += '<tr>' +
        '<td class="act-time">' + (compact ? fmtAgo(e.ts) : fmtTime(e.ts) + ' ' + fmtClock(e.ts)) + '</td>' +
        '<td>' + actBadge(e.type) + '</td>' +
        '<td style="white-space:nowrap">' + escapeHtml(e.user) + '</td>' +
        '<td class="act-detail">' + escapeHtml(e.detail) + '</td></tr>';
    });
    html += '</tbody></table></div>';
    el.innerHTML = html;
  }
  function loadActivityPage() {
    return api('GET', '/admin/api/activity?limit=200').then(function (d) {
      $('actCap').textContent = d.capacity || 400;
      renderActivityList($('actRows'), d.events || [], false);
    });
  }
  $('actAuto').onchange = function () { if (state.page === 'activity') setupPoll(); };
  $('clearAct').onclick = function () {
    if (!confirm('清空活动记录?')) return;
    api('POST', '/admin/api/activity/clear').then(function () {
      toast('已清空');
      loadActivityPage();
    }).catch(function (err) { toast(err.message, true); });
  };

  // ---- 系统 ----
  function loadSystemPage() {
    return api('GET', '/admin/api/overview').then(function (d) {
      var r = d.runtime, t = d.totals;
      $('sideVer').textContent = 'v' + r.version;
      $('sysVersion').textContent = 'v' + r.version;
      $('sysUpdateBadge').style.display = r.updateReady ? '' : 'none';
      $('sysChips').innerHTML =
        chip('版本', r.version) +
        chip('Go', r.goVersion) +
        chip('平台', r.os + '/' + r.arch) +
        chip('启动时间', fmtTime(r.startedAt)) +
        chip('已运行', fmtUptime(r.startedAt)) +
        chip('协程', r.goroutines) +
        chip('堆内存', fmtBytes(r.heapAlloc)) +
        chip('总分配', fmtBytes(r.sysBytes)) +
        chip('数据库', fmtBytes(t.dbBytes)) +
        chip('书文件', fmtBytes(t.vaultBytes)) +
        chip('单文件上限', r.maxFileMB + ' MB') +
        chip('设备闲置清理', r.deviceInactiveDays + ' 天');
    });
  }
  $('updateBtn').onclick = function () {
    var input = $('updateFile');
    if (!input.files || !input.files.length) { toast('请先选择新版本二进制文件', true); return; }
    if (!confirm('上传后服务将自动替换重启,确定?')) return;
    var file = input.files[0];
    var btn = $('updateBtn');
    btn.disabled = true;
    $('updateProgress').style.display = 'block';
    var fill = $('updateProgress').firstChild;
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '/admin/api/update');
    xhr.upload.onprogress = function (e) {
      if (e.lengthComputable) {
        fill.style.width = Math.round(e.loaded / e.total * 100) + '%';
      }
    };
    xhr.onload = function () {
      btn.disabled = false;
      var data = {};
      try { data = JSON.parse(xhr.responseText); } catch (e) {}
      if (xhr.status >= 200 && xhr.status < 300) {
        toast('新版本已写入,服务正在重启,3 秒后自动刷新');
        setTimeout(function () { location.reload(); }, 3000);
      } else {
        $('updateProgress').style.display = 'none';
        toast(data.error || ('HTTP ' + xhr.status), true);
      }
    };
    xhr.onerror = function () {
      btn.disabled = false;
      $('updateProgress').style.display = 'none';
      toast('上传失败,请重试', true);
    };
    xhr.send(file);
  };
  $('rollbackBtn').onclick = function () {
    if (!confirm('回滚将删除磁盘上的热更新版本并重启回镜像内置版本,确定?')) return;
    api('POST', '/admin/api/update/rollback', {}).then(function () {
      toast('正在回滚重启,3 秒后自动刷新');
      setTimeout(function () { location.reload(); }, 3000);
    }).catch(function (err) { toast(err.message, true); });
  };
  $('cleanupBtn').onclick = function () {
    var btn = $('cleanupBtn');
    btn.disabled = true;
    api('POST', '/admin/api/maintenance/cleanup').then(function (d) {
      $('maintResult').textContent = '已清理 ' + d.removed + ' 个孤儿目录,释放 ' + fmtBytes(d.freedBytes);
      toast('清理完成');
    }).catch(function (err) { toast(err.message, true); })
      .finally(function () { btn.disabled = false; });
  };
  $('vacuumBtn').onclick = function () {
    var btn = $('vacuumBtn');
    btn.disabled = true;
    api('POST', '/admin/api/maintenance/vacuum').then(function (d) {
      $('maintResult').textContent = 'VACUUM 完成:' + fmtBytes(d.beforeBytes) + ' → ' + fmtBytes(d.afterBytes);
      toast('压缩完成');
    }).catch(function (err) { toast(err.message, true); })
      .finally(function () { btn.disabled = false; });
  };

  // ---- 启动 ----
  Array.prototype.forEach.call(document.querySelectorAll('.nav-item'), function (el) {
    el.addEventListener('click', function () { navTo(el.getAttribute('data-page')); });
  });
  window.addEventListener('hashchange', onHash);
  document.querySelectorAll('.nav-item').forEach(function (el, i) {
    var keys = ['overview', 'users', 'books', 'activity', 'system'];
    el.querySelector('.nav-ico').innerHTML = ICONS[keys[i]];
  });
  api('GET', '/admin/api/overview').then(function (d) {
    $('sideVer').textContent = 'v' + d.runtime.version;
    enterApp();
  }).catch(function () { showLogin(); });
</script>
</body>
</html>`

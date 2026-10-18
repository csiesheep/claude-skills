---
name: agent-team-delivery
description: |
  多個 Claude session 當團隊:orchestrator 定優先序、開 issue、派工、獨立驗證後才 land;peer(FE/BE/writer…)各在自己的 worktree 實作。重點是「驗證怎麼做才算數」與「儀器自己會騙人」的失敗目錄。
  觸發:「派給 FE / BE」「幫我驗這個分支」「可以 land 嗎」「多開幾個 agent」「開子 agent」「你當 orchestrator」「orchestrator」「新專案起手 / init」;"dispatch to frontend/backend", "verify before landing", "multi-agent workflow", "act as orchestrator", "spawn subagents". 有 TEAM.md 的 repo 裡做實作時,使用者層級的 CLAUDE.md 會要求先載入本 skill。
---

# 團隊制交付 · Orchestrator + Peers

> 一個忠實模擬了可利用產品的重放器,不會偵測到那個漏洞——它只會替漏洞背書。
> 驗證的價值不在於「我看過了」,而在於「我讓它紅過一次」。

## 這個 skill 什麼時候用

當工作量大到一個 session 做不完、或需要同時推進互相依賴的幾條線時。
**不要為了「看起來平行」而開 agent。** 每個新 session 都是冷啟動,要重新建立
脈絡;只有當一條線可以獨立進行到「可交付」為止,才值得分出去。

---

## 一、角色與所有權

| 角色 | 負責 | 絕不做 |
|---|---|---|
| **Orchestrator** | 定優先序、開 issue、派工、**獨立驗證**、merge & push、對 owner 報告 | 自己動手實作(會失去驗證的獨立性) |
| **Peer**(FE/BE/writer/…) | 在自己的分支與 worktree 上實作、自測、寫 guard、交付 | 自己 merge 進 main;解不是自己造成的衝突 |

**檔案有主。** 每個檔案屬於某一個 peer。跨界修改**可以**,但必須在交付訊息裡
主動點名,由 orchestrator 轉給檔案的主人裁決。**最糟的情況不是衝突,是兩邊
安靜地各自持有一份不同的真相。**

**而在資料檔上,真正會相撞的不是行,是 id。** 兩個 peer 平行往同一張表加東西,
git 看到的只是「兩邊都往清單尾巴 append」——把衝突標記拿掉就「解決」了,而
**兩邊各自的測試都是全綠的,因為衝突只在兩邊同時存在時才存在**。

真實案例:兩支分支各自寫了一個 id 相同、內容完全不同的乘客型別(一個
`patience:56 size:3` 會卡門,一個 `patience:999 size:2` 不付錢),成就也各自
撞名。更糟的是產品用 `st.codex[p.type]` 當計數器的鍵——**id 撞名不只是資料
重複,是兩條成就讀同一個計數器**。是我 merge 完之後自己掃重複 id 才看到的。

**所以所有權要切到命名空間:要求每個 peer 在開工的第一則留言列出它這一趟要
用的所有新 id,由 orchestrator 擋掉撞到的。** 這比事後解衝突便宜一個數量級,
而且事後解衝突需要的是**設計裁決**(誰改名、為什麼),那本來就是你的工作,
不是 merge 的工作。

**而「所有 id」要真的是所有。** 下一帶我做了這件事——要求兩個 peer 列出新 id,
自己去掃分支,**在合併前抓到它們各自定義了同兩個乘客型別**。規則生效了。

然後合併的時候還是紅了:**它們也各自寫了同兩條成就**,而我掃的時候只對了
乘客那張表。**同一個檔案裡有幾張表,就有幾個命名空間**,漏掉哪一張,那一張就
會照原樣出事。

這一次沒有變成事故,只因為**我在上一輪剛好加了兩條 guard**(「成就的門檻要跟
中英文案一致」「兩個型別不可以顯示同一個名字」),它們在合併後的第一次執行就
同時咬住,而且訊息直接點名是哪兩條。**沒有那兩條 guard,兩條重複的成就會安靜
上線**——id 相同、codex 鍵相同、只有門檻不同,遊戲照跑。

判準:**列出你的資料檔裡每一個「有 id 的清單」,把它們全部放進交叉檢查**,
而不是只查你上次被咬的那一張。

**Orchestrator 不寫產品程式碼。** 一旦寫了,後面就是自己驗自己——這是本
skill 想避免的第一件事。寫探針、寫破壞測試、寫驗證腳本可以;那不是產品。

**如果你在切換角色之前就已經寫過產品程式碼**(常見:你先做了 phase 1,才
決定改當 orchestrator),不要假裝沒發生:

1. **主動申報**,對 owner 也對 peer。
2. 把那部分當成**全系統驗證最少的地方**,而不是最可信的——它沒有經過任何
   獨立的眼睛。
3. 明確告訴 peer:「**如果你在那段程式碼裡找到缺陷,先假設是我錯,不是你
   錯。**」否則他們會繞過去,而不是回報。

真實案例:文件、實作、測試三份都出自同一個腦袋,於是三份**一致地錯**。它
之所以被抓到,只因為驗收 harness 是從設計文件的另一段獨立敘述期望值。

---

## 二、派工:一份好的 brief 長什麼樣

派工不是轉貼 issue 標題。一份能讓 peer 一次做對的 brief 有五塊:

1. **裁決(ruling)與它的理由。** owner 說了什麼、為什麼。peer 會遇到你沒
   想到的取捨,它需要知道判準才能自己決定。
2. **不可協商的約束**,而且要說明「錯了會怎樣」。
   例:「這個閘門必須 fail open——取不到資料時要**顯示**按鈕。隱藏會把一筆
   真實紀錄無聲丟掉,玩家永遠不知道。被拒絕可以再來,沒被提供不行。」
3. **明確不要做的事**,以及邊界在哪。
4. **要怎麼證偽**——指定那個「會咬人」的案例。
   例:「證偽案例必須在第一個元素平手、在後面的元素分勝負;若在第一個元素
   就分出高下,錯誤的實作也會通過,等於沒證明任何事。」
5. **遇到什麼情況要停下來問我**,而不是自己想辦法繞過。

**brief 裡關於現有程式的每一句話,派出去之前自己跑一次。** peer 會照它寫程式,不會懷疑;
寫錯了,它會把一個正確的函式換掉。查得到就把數字寫進去(「8 次搬家都差一年」),查不了就寫「我猜」。
見 [unchecked-brief-claim]。

**owner 的回饋先變成裁決,才變成 brief。** owner 的一句話或一張手機截圖 → 設計文件的一節(逐字引用原話、
寫主詞與日期)→ 驗收(新要求先記 TODO)→ issue。不要把截圖直接轉給 peer:它拿到的是一個畫面,
不是判準。owner 常在手機上看——要給他看的東西(截圖、設計稿)存成圖檔送過去,對話裡的 widget 在手機上看不到。

### 一定要寫進去的一句話

> 如果做不到 X,**回報我,不要自己降規格**。

縮小範圍是 owner 的決定,不是 peer 的。這一句話在真實專案裡救回過一次
設計意圖被安靜推翻的情況(五張牌塞不下時,peer 沒有偷偷把牌縮小,而是
帶著實測數字上報,由 owner 裁決)。

### 但這句話一定要配一份「你可以自己做什麼」

**只講「有事回報我」而不講授權範圍,peer 會卡在一個永遠不會到的確認上。**

真實案例:一個 peer 完成並通過驗證之後,停了一小時沒有 push。它不是在等我
——**它去問了 owner**。因為從它的 session 內部看,那個人類才是它的使用者,
我只是一個外部訊息來源。我花了一小時診斷它「卡住」,實際上它在等一個我
根本不知道存在的確認。

所以 brief 裡要有三欄,而且要寫死:

| | 例子 |
|---|---|
| **不必問,直接做** | 我已確認驗證通過的東西;自己區域內、能維持測試全綠的修正 |
| **先問 orchestrator** | 跨進別人的區域;更動設計文件裡的數值;會讓 guard 變紅的改動 |
| **不要問 owner** | 一律走 orchestrator。你握有全局脈絡,而且只有你能同時碰到所有 peer |

最後一列特別重要:**peer 之間通常沒有通道,只有 orchestrator 有。** 所以
「你去跟 FE 談好」這種指示是**無法執行的**——我下過一次,對方就地卡住,而
那看起來跟「它掛了」一模一樣。需要另一個 peer 的決定,一律由你居中轉。

**這三欄必須寫在第一份 brief 裡,不能等到出事再補。**

我第一次漏掉時,BE 卡了一小時去問 owner。我補了授權給 BE,**然後 FE 一小時
後做了一模一樣的事**——因為 FE 的 brief 也漏了同一欄,而我的更正是**逐一
發的**,補了一個不會補到另一個。

兩件事讓「事後補」永遠來不及:

1. **你發現對方被擋住的時候,它已經去問過人了。** 授權是為了讓那次詢問不
   發生,補在後面只能救下一次。
2. **這是 per-peer 的洞。** 每一個沒拿到那三欄的 peer 都會各自踩一次,而且
   症狀完全相同(安靜、無進度、看起來像當機),你會重新診斷一次。

所以它屬於**派工樣板**,跟「回報我,不要自己降規格」那句話並排——那句講
**什麼時候要停下來**,這三欄講**什麼時候不必停**。只給前者,peer 會停在
所有地方。

---

## 三、交付:一份好的 handover 長什麼樣

要求每個 peer 用固定格式回報:

```
分支 / SHA / base(是否已 rebase 到最新 main)
測試結果(數字,不是「通過」)
證偽:我讓哪一條 guard 紅過?紅的時候它說了什麼?
我改了什麼不屬於我的檔案
我沒有驗到的部分(以及為什麼)
```

**「我沒有驗到的部分」是最有價值的一欄。** 它決定 orchestrator 要親手做
什麼。真實例子:BE 明講「binding 在 isolate 裡解析、D1 的行為、路由——
這三件事部署前無法測」,那就正好是 orchestrator 部署後唯一該做的事。

**資料型的交付多一欄:最沒把握的十項。** writer 交史料、出處、對照表時,要它列出最沒把握的十個項目
(哪一列、為什麼、取了哪個說法)。你抽查從這十項開始,不從第一列開始。出處只能寫真的查到的,
不編;拿不準的取通說,信心欄只用固定的幾種值(例:史料／學界估計／模型推估)。

---

### 回程:不要要求宣告,要製造痕跡

「做完回報我」是一個**需要雙向通道**的設計,而通道**兩端都可能在睡**。
[dispatch-not-delivered] 講的是去程會安靜地失敗;回程一樣會,而且多一個問題:

> **peer 可能根本找不到你的位址。** 當前 session 通常會被自己的 session
> 列表排除——你查不到自己是誰,也就給不出回信地址。你寫「done 之後告訴
> 我」的時候,可能從來沒有存在過一條回信的路。

改成**單向拉取**。要求 peer 留下痕跡,而不是送出通知:

| 要求 peer 做的 | orchestrator 怎麼看到 |
|---|---|
| 在 issue 留言(帶那五行) | `gh issue list` / `gh api .../comments` |
| push 到分支或 main | `git fetch` |
| 開 PR | `gh pr list` |

三個都不需要通道活著、不需要對方醒著,也不需要你醒著。

### 再讓痕跡叫醒你

痕跡解決了「看得到」,沒解決「什麼時候去看」。放一個**背景哨兵**:

```
baseline = 快照(origin/main、各分支 SHA、各 issue 留言數、issue 狀態)
每 N 秒重新快照;和 baseline 不同就:
    印出 diff
    印出新留言的「內容」,不只是數量
    exit 0
設一個死線(例如一小時),到了就結束,讓上層重放
```

關鍵不是輪詢,是**它在有事發生的那一刻結束**——而一個結束的背景任務會**自動
重新叫起 orchestrator**。於是輪詢變成事件觸發,而且完全不依賴 peer 的合作。

哨兵結束時要把**新留言的內容一起印出來**。否則你醒來只知道「有事發生」,還
得再花一輪去問發生了什麼。

**分清楚「完成訊號」和「活動」。** 第一版哨兵我把 peer 的功能分支也列進觸發
條件,結果它在對方每一個 work-in-progress commit 上都把我叫醒——那是「他正在
打字」,不是「他做完了」。

| | 例子 | 該不該叫醒你 |
|---|---|---|
| 完成訊號 | issue 留言、push 到 main、開 PR、issue 關閉 | **會** |
| 活動 | 功能分支上多了一個 commit | 不會,但**觸發時一起印出來當脈絡** |

判準:**這個訊號是 peer 「刻意發出」的,還是它工作時「順手留下」的?** 只有
刻意發出的才算交付。

**哨兵從派工的那一刻就放,不是等到你覺得它快交了。** peer 在做到一半就會提問:
驗收的洞、草稿沒寫到的牌、一句兩種讀法。真實案例(president_2000 #55):BE 開工後
在 issue 留了三則「問 orchestrator」,其中兩則是驗收本身的錯,而我沒放哨兵,一則都沒
看到;它只好照暫定的讀法做完,兩個洞到交付時才一起回來。之後每張單派出去就同時
放一個只盯那張 issue 留言的哨兵,下一張(#58)的提問在 90 秒內就被接住。
brief 也要寫明:「驗收哪一條看起來不對,**一發現就留言,不要等交付**」。

## 四、驗證:orchestrator 的核心工作

### 4.1 從乾淨的、抽離的 worktree 驗

```bash
git worktree add --detach <tmp> <明確的 SHA>
```

**不要在 peer 的工作目錄驗。** 它有未提交的檔案,你會量到不是它交付的東西;
更糟的是你可能把它的東西一起 commit 掉。

**detached worktree 還有一個附帶好處**:它不能 push,所以不會誤觸生產線。

### 4.2 驗證 = 讓它紅一次

**看過程式碼不算驗證。跑過測試也不算。** 唯一算數的是:

> 我把產品弄壞,那條 guard 有沒有紅?紅的時候它說的話對不對?

破壞要下在**產品**上,不是在 fixture 上。對著手寫的假資料弄紅一條測試,
證明不了那條測試能保護真的程式碼。

每次修改 guard 之後,**證偽要重跑**。改過的 guard 不再享有先前那次證偽的
背書。

**而且證偽要一個一個下。** 一次注入多個缺陷,**紅的數量會對,但每一個紅的
理由不一定對**。

真實案例:我一次下三個缺陷,三條新 guard 都紅了,看起來三條都被證偽了。
實際上第二條紅在「母體是空的」——第一個缺陷(型別 id 打錯字)讓第二條 guard
的查表回傳 undefined,於是它整批 `continue`,母體被清空。**那條 guard 那一次
根本沒有檢查任何東西**,而我差一點把那個紅記成「它有效」。

擋下它的是我寫在 guard 裡的母體非空斷言([nonempty-population] / [red-capable-vs-alive])。單獨再下一次那個
缺陷,它才真的紅在該紅的地方。

**判準:一次一個缺陷,而且讀的是紅的「理由」不是紅的「數量」。**

### 4.3 A/B 是最強的證據

同一支探針、同一個方法,只換 build:

```
                  修正前          修正後
記錄的動作         0 → 1          0 → 0
eventRng      2567497118 → 104095635   不變
```

兩邊都跑在真正的產品上,差異只有那一個 commit。這比任何測試報告都難以爭辯。

### 4.4 眼睛是不可替代的儀器

**測試會驅動引擎,但沒有人把畫面畫出來。** 在真實專案裡:280 個測試 + 大量
機器人跑分,照樣讓結算畫面印出三句假話;399 個測試,照樣讓標題和統計列擠
在一起沒有間隔。

所以:**凡是「存在目的就是被人看」的頁面,先打開看,再跑套件。**
而且要有能力回答「我現在看到的,是我剛才 ship 的那一份嗎?」(見 [stale-cache])。

---

### 4.5 先寫驗收,再等實作

在 peer 交付**之前**就把驗收標準寫成會跑的檢查。這不只是為了快——**實作還
不存在的時候,你的期望值不可能被它污染**(見 [circular-expectation])。

三件事讓它真的獨立:

- 常數從**設計文件抄寫**、寫死在 harness 裡,不從產品的設定檔讀。
- **先拿產品的設定去對這些常數**。這樣「改產品裡的數字來讓行為測試通過」
  會在對照那一關就爆,而不是安靜地通過。
- 用**三態**:通過 / 失敗 / **尚未實作**。把「還沒做」和「做了但錯」混成
  同一種紅色,一整張 issue 可以在功能不存在的情況下被標記成完成。

harness 由 orchestrator 所有。peer 可以跑,但不編輯——某一列錯了要回報,
由你修。

**三態的閘門在 land 之後要翻過來。** 「尚未實作」只在功能還不存在時才對;一旦
land,同一個條件再出現就是**退步**,要報失敗。不翻的話,有人把新局改回舊版本,
整段驗收只會安靜地變回「尚未實作」,exit 0。**在 land 的同一次就翻**:merge 後面接一個翻閘門的 commit,
一起 push;並證偽一次(把功能拿掉,看它從 0/0/N 變成 0/N/0、exit 1)。閘門寫成看得見的開關,翻的時候改一個字:
資料帶版本旗標(`v: 2` 之前記 TODO)或一個 `STRICT` 常數。
新要求加在**已經上線**的東西上時同理:先記 TODO(不讓 main 變紅),land 那一次翻嚴格。

**驗收先在探針上看紅也看綠,再交出去。** 開一棵抽離的探針樹,只做最少的改動
(例如只把新局切到新版本):每一條要紅在自己的理由上;再補一個「做對了」的探針,
看綠的那一列印得對。產品在探針上會當掉的話,先把當掉的地方補掉再看,否則當掉
會蓋住後面每一條自己的判斷。探針不 commit。

**換版本之前,先掃驗收裡寫死舊版本的地方。** 每次切換(v0.5 → v0.6 → v0.7),都有
上一版寫死的測試在「owner 要的那個切換」上反咬:常數(連的候選人牌 3 CP)、字樣
(候選人板上的「袋中 N」)、閘門只認一個版本字串。派工前 grep 舊版本的名字、常數
和字樣;守「這一版與建在它上面的版本」的,寫成清單(`ON = ["v0.6", "v0.7"]`)。
見 [pinned-to-the-old-version]。

### 4.6 驗收沒過就退回,不要開一張新 issue

流程只有一條:

> **peer 實作完成 → orchestrator 驗收 → 沒通過就繼續作,通過才關 issue。**

聽起來理所當然,而它失守的樣子不長那樣。**它長得像盡責。**

真實案例。一張 issue 的裁決是「把這個事件改成**會痛**」。peer 交付了:機制正確、
證偽做足、而且**它自己誠實回報「最糟一次只流失 1–2 人」**。我驗完之後——

1. 稱讚它誠實回報(對的)
2. 把「不夠痛」開成一張新 issue,標題寫「要 owner 裁決」(錯的)
3. 把原本那張標記為完成、關掉(錯的)

三個動作每一個單獨看都像在盡責:我沒有隱瞞、我留了痕跡、我把決定交給有權決定的人。
**但合起來的效果是:一件沒做完的事被記為做完了,而 owner 的待辦多了一條。**

### 為什麼這個錯特別容易犯

因為 peer 誠實回報的**缺口**,和真正需要 owner 裁決的**取捨**,在報告裡長得
一模一樣——兩者都是「這裡還有問題,你看一下」。

判準只有一個,而且要問對:

> **這件事沒達成,是因為「還沒做完」,還是因為「做完了才發現原本的方向不對」?**
>
> 前者退回 peer。後者才是 owner 的。

- 「事件不夠痛」→ 驗收條件就是「要痛」,**還沒做完**,退回。
- 「三個候選都不值那個價,因為這個經濟裡沒有可以兌現的地方」→ 裁決的**前提**
  被推翻了,peer 再做也不會變,**這才是 owner 的**。

### 附帶的兩個徵兆

- **你正在寫一張新 issue,而它的內容是「原本那張沒達成的部分」。** 停下來。
  那不是新 issue,那是原本那張的現況。
- **你正在關一張 issue,同時心裡想著「剩下的另外處理」。** 那句「另外處理」
  就是它還沒做完。

### 還有一件事要在 brief 裡先講清楚

我退回那張 issue 時才發現,peer 之所以沒調參數,是因為我在派工單裡寫了
「**不准自己調**」。我的用意是「不要為了讓數字好看而調」,它讀成「不准調」——
**兩種讀法都合理,是我寫得不夠精確**,而它照著比較保守的那個做,沒有錯。

所以約束要寫出**它在防什麼**,不要只寫禁令:

> ❌ 不要自己調參數
> ✅ 不要為了讓數字好看而調參數。為了達成裁決而調是你的工作——
>    調到你認為過頭時停下來回報,不要自己往回收。

**一條沒說出理由的禁令,會在你沒預料到的方向上被遵守。**

## 五、失敗目錄:儀器自己會騙人(索引)

全文在 [`references/failure-catalog.md`](references/failure-catalog.md)(症狀 / 為什麼騙人 / 判準),
原始敘事在 `references/failure-catalog-stories.md`,兩者**按需讀**——
驗證前把這份索引掃一遍,對上症狀的那一條再用 `grep -n '^### \[slug\]'` 跳進去。
方括號是條目的 slug;本檔其他地方的 `[slug]` 也都指向那裡。

每一條都真的發生過,而且都是在很用心工作的時候發生的。

**儀器與環境——量到的不是你以為的東西**

- `[stale-cache]` 換 origin 不是重新整理;量之前先讀版本戳記;`curl` 沒有 service worker,是裁判
- `[someone-elses-server]` 量之前先證明那個 origin 是你的——種一個只有你的 build 會回傳的標記
- `[synthetic-events]` `el.click()` 是 Enter 的簽名;合成 tap 沒有 hover,對 `:hover` 分支毫無證據力
- `[hidden-pane]` 隱藏 pane 計時器被節流、動畫永不結束、`innerWidth` 為 0;「解卡幫浦」會製造新的假失敗
- `[measure-the-container]` 自適應元素量自己永遠「放得下」,要量容器;JS 掛上的元素從靜態 HTML 推算看不到
- `[rounding-at-threshold]` 「≥ 門檻」的比較之前不准格式化;問儀器解析度跟門檻差幾個數量級;分母要跟兩端一起固定
- `[pipe-eats-exit-code]` `|` 回的是最後一段的狀態;「還原」不能是 `&&` 鏈上的一步,要寫成下一步的守衛;`grep -c` 為 0 時 exit 1
- `[shared-browser-tab]` 瀏覽器 pane 所有 agent 共用;有 peer 在跑就開專屬分頁帶 tabId,讀結果連 `location.href` 一起印
- `[headless-min-width]` 只設 `--window-size=390` 的 headless 不是手機:視窗有最小寬度,截圖只切了左邊;手機一律用 CDP 模擬
- `[dead-dev-server]` 伺服器是你的還不夠,要證明它還活著:切版本、移 worktree 會讓 dev server 卡死,量之前 `curl -m 5`
- `[deploy-tree-not-test-tree]` 部署會挑檔,就對挑出來的那棵樹再查一次(相對 import 都解析得到),排在上傳之前
- `[offscreen-transitions]` 畫面外的 iframe 不跑過渡:用 DOM 插入計時、讀樣式前 `finish()`;整套用無頭 Chrome 跑,`--user-data-dir` 要短路徑

**假綠——guard 本身是死的**

- `[circular-expectation]` 把規則改錯,期望值會不會跟著錯?會就沒用——期望值要獨立手寫
- `[verify-in-working-range]` 先說出驗證取樣了哪個區間、總共有哪些區間;飽和 / 夾限 / 釘死的邊界就是區間分界
- `[name-promises-more]` 測試名字承諾的,斷言有沒有做到?要嘛補斷言,要嘛改名
- `[nonempty-population]` 「必須不包含 / 必須沒有改變」的檢查,先斷言母體非空
- `[unfalsified-guard]` 問「我沒證偽過哪些、為什麼跳過」——地基型、一直綠、常被引用的就是那幾條;排空型 API 別丟回傳值
- `[red-capable-vs-alive]` 「能紅」是程式碼的性質,「這次瞄對」是那次執行的性質;存活證明放進 guard 本身
- `[cleanup-as-precondition]` `finally` 擋不住被殺掉;清理寫成下一次開頭的前置檢查,不是這一次的收尾
- `[green-path-unseen]` 為通過寫的輸出,去看一次通過的那一列;失敗路徑天天被證偽,成功路徑沒有人看
- `[guard-punishes-completion]` 把守護的東西做到完美,guard 是什麼顏色?必須是綠;「數量 > 0」先問那個 0 是不是勝利
- `[product-verb]` 這個產品的動詞是什麼?哪條檢查會因為它停擺而紅?答不出就先寫那條,門檻要鬆
- `[dead-branch-fix]` 寫下條件先問「今天有幾筆資料讓它成立?」0 = 永不執行的分支,而測試不會告訴你
- `[vacuous-consistency]` 「A 跟 B 一致」在兩邊都空時恆真——A 先對獨立來源的絕對值;認本尊別用被檢查的欄位
- `[shell-ate-the-escape]` 經 heredoc / `node -e` 產生的 guard 少了反斜線:`\b` 變 backspace,正規式一個字都抓不到;用檔案工具寫,掃控制字元
- `[random-walk-misses-rare-state]` 隨機走的 guard 走不到罕見狀態;數那個分支被執行幾次,0 就補人為設定的局面
- `[pinned-to-the-old-version]` 換版前先掃驗收裡寫死舊版本的常數、字樣、閘門;守一版的寫成「這版與建在它上面的」清單
- `[todo-hides-broken]` 可選 import 只在「找不到檔」時回 null;載不起來是紅,另有一組 import 每個出貨模組
- `[present-not-exclusive]` 比對兩邊都斷言:對的在,而且最像的錯值不在
- `[two-tables-one-fact]` 兩張表編碼同一個事實,就逐單位互比,並規定哪一邊是真相

**取樣與數字**

- `[discriminating-points]` 只在能分辨兩種解釋的點取樣;N 處描述同一件事,全列出來看誰跟誰一致
- `[initial-state-sample]` 取樣清單要有預設值 / 初始值 / 空的 / 第一次執行——權重最高的點不在等距序列裡
- `[grid-count-not-absolute]` 取樣網格數出來的計數,報出去換成比例或把網格寫在同一句;粗網格的 0 不是「不存在」
- `[asymmetric-samples]` 比較兩個 arm 之前先把樣本數寫在同一行;鬆的那組若剛好支持你想做的,先補那一組
- `[wrong-criterion]` 修法是「再改一個本來就好的地方」→ 懷疑判準不是資料;真規則常是連續量;背書要逐項
- `[compare-to-the-exact-value]` 畫面上的數字跟精確值比,不跟紀錄裡已經捨過的值比——容許 0.5 會放過「捨兩次」
- `[one-sample-per-interval]` 每區間只取中點會漏掉區間內的變化;數得完就逐單位,數不完就取每個變化點兩側
- `[population-cannot-discriminate]` 先寫出最像的錯實作,專收兩者答案不同的案例,數量 ≥ 下限,不只非空

**主張與規格——句子本身騙人**

- `[true-sentence-wrong-scope]` 否定句要配「還證明得了什麼」,否則讀者把範圍補得比事實大
- `[report-is-a-reading]` peer 說的「現況」是那一刻的讀數;轉述前自己讀那個值(`git log -S`);標籤要寫出被固定的變數
- `[naming-is-not-scanning]` bug 被命名成類的那一刻,下一步是 grep,寫心得之前跑;先掃自己的檔案
- `[lesson-not-self-applied]` 教訓寫進 brief 的那一刻,先對自己的檔案跑一次;派工只是轉發,不是處理
- `[size-not-hit-target]` 尺寸是元素的屬性,可及性是「加上之後畫的所有東西」;斷言中心點上最上層是不是它自己
- `[no-scroll-not-fits]` 沒捲軸 ≠ 裝得下——被丟掉的溢出分數更好看;斷言「畫了幾個 vs 擁有幾個」;會數數的 guard 不會判斷
- `[counts-from-their-own-line]` 從合併的測試輸出讀各段數字,要讀該段自己印的那一行,不是照順序對檔名
- `[unchecked-brief-claim]` brief 裡關於現有程式的每一句,派工前自己跑一次、寫上數字;查不了就寫「我猜」

**通道與協作**

- `[dispatch-not-delivered]` `success:true` 只是位址解析;先看 `isRunning`,再去對方 transcript 搜自己的字串;確認送達前不要開始等
- `[diagnosis-outlives-validity]` 修好機制後,把所有「因為它壞」的結論標為待重驗;「安靜」先分「壞了」還是「做完在等」
- `[question-while-you-wait]` peer 做到一半就會提問;哨兵從派工那一刻放,只盯那張 issue 的留言,不是等它快交了
- `[shared-append-file]` 平行往同一檔案尾巴加東西必衝突:brief 先說「兩邊都留」;全域檢查依檔案分開記 TODO

---

## 六、比較數字時:兩端要來自同一支儀器

一個比較有兩個運算元。**如果其中一個是你繼承來的、或用別的方法量的,那個
比較不成立。**

真實案例:我說「五張牌比現在的四張矮」,五張是我用正確方法量的,四張是我
沿用別人的數字。重量之後才發現兩者環境不同——結論碰巧沒變,但當時我沒有
資格那樣說。

第二個真實案例,同一週:我要驗一個「畫面上的每秒收入」準不準,螢幕讀到
$1.86,我自己量出 $2.09,差 11%——已經準備把它當缺陷寫進 issue 了。實際上
螢幕給的是**當下瞬時值**,我量的是**六十秒平均**,而那六十秒裡品質分數正
從 100% 一路掉到 77%。用同一個時點、同一種統計量重量:2.4%。

**這一條的第二個維度是時間。** 除了方法、origin、區間之外,還有:

- **同一個時點**——瞬時值 vs 平均值是兩個量,不是同一個量的兩種精度。
- **同一個安定狀態**——系統還在往平衡收斂的時候,任何跨越那段過渡期的
  平均,量到的是路徑,不是值。

**規則:同一個方法、同一種 origin、同一個區間、同一個時點與安定狀態,
現場重量兩端。**

**而且:當兩個數字對不起來,先假設是儀器,不是產品。** 這一週我三次遇到
「兩個數字用不同方法量」,三次都短暫相信差異是真的。差異看起來越像一個
合理的缺陷,越該先回頭看儀器——因為一個合理的缺陷,正是你會停止追問的地方。

---

## 七、Land 的紀律

1. **在抽離的 worktree 上 merge**,不要在任何 peer 的目錄。

1b. **驗哪一個 SHA,就 merge 哪一個 SHA。** 四之 4.1 要你用明確的 SHA 開 worktree
   ——然後 merge 的時候很自然就會打分支名,而 `git merge <分支名>` 解析的是
   **「現在」的 ref**,不是你驗過的那一個。

   真實案例:我用 SHA 開 worktree、做完 A/B、寫進 merge message,而 peer 在那
   之間又推了一個 commit(把一個上限從 4 改成 3)。我**驗了一個 SHA、land 了
   另一個**。合併後的測試我有跑、是綠的,所以功能面沒事;壞掉的是**紀錄**
   ——merge message 裡那段帶著數字的文字,描述的不是它下面那棵樹。

   這是 [report-is-a-reading](「peer 的回報是一次讀數,不是樹的屬性」)套用在**自己的 git 操作**
   上:分支名也是一次讀數。**merge 的時候貼那個 SHA。**
2. Merge 後確認**父節點是預期的兩個**,以及 merge 的結果樹沒有多出東西:
   ```bash
   git log --format="%H %P" -1 <merge>
   git diff <merge> <被合併的分支> --stat   # 應為空(若對方已含 main)
   ```

2b. **先在本機做出 merge,讓 checker 驗那個 merge 的 SHA,驗過才推。** 在你交出驗收
   之後、peer 交付之前,main 常常又多了 Harness commit;peer 的分支驗過,不等於
   「main + 它」驗過。merge 物件在共用的 `.git` 裡,checker 的 worktree 直接
   `checkout --detach <merge>` 就看得到;驗的、推的、部署的,是同一個 SHA。
   瀏覽器工具要量的話,讓本機 dev server 跑在 merge 那棵樹上,先逐位元組確認它送的
   就是那幾個檔。(president_2000 #55–#63 都這樣 land。)
3. **main 若是生產線,land 就是 ship。** 「這會不會退步?」和「這該不該
   上線?」是兩個問題。
4. **分支上游陷阱**:`git checkout -b X origin/main` 會讓 X 的上游指向
   `origin/main`,一個裸 `git push` 就直接部署。**`git worktree add -b X
   origin/main` 一樣會**——而每個 peer 的 worktree 都是這樣開的,所以這個
   地雷會被**複製到每一個 peer 身上**。派工時就叫它們
   `git branch --unset-upstream`,或推之前先
   `git rev-parse --abbrev-ref @{upstream}`。真實案例:兩個 peer,一個有上游
   一個沒有;**沒設上游的那個反而安全**,裸 push 會直接報錯。

5. **rebase 要緊貼著 push,不是開工時做一次。**

   ```
   git fetch origin && git rebase origin/main && git push origin HEAD:main
   ```

   理由不是衝突,是**過期**。「我 rebase 過了」和「我 push」之間那段時間,
   正好是其他人 land 東西的時候。

   而 **push 被拒之後的收拾,比被拒本身危險。** 真實案例:我的本地 main
   過期,commit 長在舊基底上,push 被拒;事後對齊時我用了 `reset --soft`,
   **index 仍然握著舊的樹**,`git status` 顯示 `game.html` 被 **staged 成還原
   回上一個 phase**。那個當下任何人 commit,都會把兩個 peer 的工作從 main 上
   抹掉。

   所以:**push 失敗之後,先把 `git status` 的每一行讀完,再做下一件事。**
   還原一個檔案之前,先證明它只是過期、而不是誰的未存編輯:

   ```
   git show <old-sha>:<file> | diff - <file>    # 位元組相同才動它
   ```

6. **共用工作樹裡有別人的未提交檔案時,不要 stash、不要 commit、不要
   `reset --hard`。** 需要乾淨基底就開一個自己的抽離 worktree,cherry-pick
   過去再從那裡推。真實案例:rebase 被「有未暫存變更」擋住,而那些變更屬於
   第三個 session——繞過去比清掉它安全得多。

7. 有「產生檔案」(shell 摘要、快取名)的專案,錄製要**兩趟、中間有 commit**
   ——因為腳本會改寫它自己要雜湊的檔案。
8. 部署後才驗:**靜態資源和 Worker 是分開部署的**,兩者不同步的空窗期會讓
   你把「還沒部署」誤判成「路由壞了」。
9. **部署的時機寫在 `TEAM.md`,不是每次臨場決定。** push 到 main 不一定會部署(有的專案要手動跑部署指令),
   而「這該不該上線」是 owner 的問題(第 3 條)。`TEAM.md` 的「部署」一節寫死:什麼時候部署(例:上線前每次
   land 之後;上線後只在 owner 說 go 時)、誰部署(orchestrator;peer 絕不部署)、用什麼指令。沒寫 → 問 owner,
   不要自己挑。
   部署跟 merge 同一條紀律:**land 哪個 SHA,就部署哪個 SHA**,從那個 SHA 的乾淨 worktree 跑(需要時先裝相依),
   不從 peer 的目錄、不從有未提交檔案的樹。部署後逐位元組比對線上檔案,比對過了才報「已部署」。
   **測過的樹不是部署的樹。** build 會挑檔(白名單、打包、搬進 `public/`)時,上傳之前對挑出來的那棵樹
   再查一次:每個相對 import 都解析得到(starter 的 `tools/check_public_imports.mjs`)。新增一個被 import 的
   資料夾卻沒進白名單,線上整頁就載不起來,而所有驗收都是綠的。見 [deploy-tree-not-test-tree]。

---

## 八、對 peer 說話的方式

- **指名它做對的事,而且說出為什麼對。** 「你自己抓到那個循環檢查」比
  「做得好」有用一百倍——它會知道要繼續做哪一件事。
- **更正要具體、要快、要不帶情緒。** 弄錯了就直說,並且把記錄更正到位:
  「我的警報比事實大聲。你不是在修損害,你是在補一個缺口。」
- **peer 糾正你的時候,先驗證再接受。**
  > 整個 session 裡唯一沒有查證就接受的說法,正好就是讓我出錯的那一個。
  > 認錯的感覺很像嚴謹,但它不是。
- **要求它「回報而不是繞過」,然後真的在它回報時做決定**,否則下次它就自己
  繞過了。

---

## 八之二、授權:不要用別人的名義發布你的推論

全文(兩次真實事故的路徑)在 [`references/authorization-drift.md`](references/authorization-drift.md)。判準:

- **記錄別人的授權時,逐行逐字引用並標出處。** 你推論的部分放在另一個標題底下,
  明講那是你的、可以被反駁。**引不出原話,就不是授權,是計畫。**
- **下裁決時一律寫出主詞。** repo 若只有 `owner 裁決(#NN)` 一種標記,就建立第二種
  (`orchestrator 裁決(#NN)`)——沒有標籤可用時,下游會借用最像的那一個,而最像的
  正好是最貴的誤讀。
- **peer 要標出處而手上沒有正確的標籤時,回頭問,不要挑一個最像的。**
- **下游拒絕你的授權主張時,那是要獎勵並記錄的行為**,不是用更肯定的重述壓過去
  ——原話再貼一次,仍然是從你的訊息裡送達的。
- **假的 attribution 要 amend 進原 commit、逐 commit 掃**,不是只改 HEAD;歷史裡的
  「當事人已同意」仍可被 `git show <sha>:file` 引用。
- **當「你已經有許可了」變成承重、而下游無法查證,先問「能不能重新安排成沒有人需要
  這個授權?」** 再問「我要怎麼證明」。本例的解法是回到第一節的分工:peer 只交分支,
  orchestrator merge & push——一個從不推生產線的 peer,不需要評估任何轉述的同意。

---

## 九、擴充到更多角色

同一套規則,只是所有權切得更細:

- **writer**:文案、規則書、README。所有權是「玩家看得到的字」。
  它的 guard 通常是「同一個事實只有一處定義」而不是單元測試。
- **simulator / balance**:跑大量模擬、產出分佈。
  **注意 [circular-expectation]**:它最容易寫出「用被測模型產生期望值」的檢查。
  要求它報告**分佈與離群**,不要只報平均。
- **artist / SVG**:視覺產出。**[true-sentence-wrong-scope] 與四之 4.4 對它最重要**——
  幾乎所有缺陷只有眼睛看得到,而且「一次只看一張」看不出來的問題
  (色偏、雷同、框線)要**併成一組**才會現形。

新增角色時,先回答三個問題:
1. 它擁有哪些檔案?
2. 它的產出**怎麼樣算錯**,而那種錯**誰看得見**?
3. 它交付時,哪一欄是它「無法自己驗證」的?

---

## 十、一頁速查

**派工**:裁決 + 理由 / 約束 + 錯了會怎樣 / 不要做什麼 / 怎麼證偽 / 何時該停下來問
→ **三欄授權**(不必問 / 先問我 / 不要問 owner)寫在**第一份** brief,事後補是 per-peer 的
→ 平行動同一張資料表時,要求 peer 先列出它要用的**所有**新 id(每張有 id 的表都是一個命名空間)
→ peer 之間沒有通道,需要另一個 peer 的決定由你轉;派完去對方 transcript 搜自己的字串確認送到
→ 派給角色的 agent(`peer-be` / `peer-fe` / `peer-writer` / `peer-artist` / `peer-chore`),模型跟著角色走;退回用 `SendMessage` 接同一個 agent(§十三)

**交付**:SHA + base / 數字 / 我讓什麼紅過 / 我碰了誰的檔案 / 我沒驗到什麼
→ 回程製造痕跡(issue 留言 / push / PR),不要要求宣告;放哨兵把痕跡變成叫醒你的事件

**驗證**:實作之前先寫驗收 → 抽離 worktree → 先看畫面 → 跑套件
→ 破壞**產品**讓 guard 紅一次(一次一個缺陷,讀理由不讀數量)→ A/B
→ 沒通過退回 peer,不要開新 issue;判準是「還沒做完」還是「方向被推翻」
→ 兩個數字對不起來,先懷疑儀器:掃一遍第五節的索引

**Land**:抽離 worktree merge **驗過的那個 SHA** → 檢查父節點 → rebase 緊貼 push
→ push 被拒先讀完 `git status` 再動手 → 每個 peer 的 worktree 可能繼承 `origin/main` 當上游
→ 部署照 `TEAM.md` 的「部署」一節:land 的那個 SHA、乾淨 worktree、部署後比對位元組才報

**預算**:一張 issue 一個 session;orchestrator 讀判決不讀全文;原始輸出先落檔再取答案;
問「冷 session 能不能只靠痕跡接手?」

---

## 十一、上下文預算:狀態放 repo,session 當耗材

> 草稿(2026-09-07)。這一節還沒有經過第五節那種程度的驗證——它來自一次「token 越燒越快」的診斷,
> 不是來自一次失敗。踩到反例就改。

### 為什麼會越燒越快

一個 session 每個 turn 都把整段歷史重送一次。context 每輪長 c,做 N 輪的累積成本是
**O(N²)**——不是你做的事變多了,是**同樣的事每一輪變貴**。prompt cache 讓前綴打折,
但前綴仍然逐輪變長,cache read 也一樣計進用量。體感是「前 20 輪很便宜,第 60 輪突然很兇」。

在這個架構裡長得最快的是 orchestrator:它是唯一同時讀到所有 peer 產出的角色,
卻也是活得最久的那一個。複利的最壞組合。

### 第三節的痕跡制,其實是 checkpoint 機制

「不要要求宣告,要製造痕跡」原本是為了解決「通道兩端都可能在睡」。但它真正的威力在別處:

> **如果所有狀態都在 issue 留言、分支 SHA、PR 上,那一個 session 就是可拋棄的。**

認到這一點,規則就跟著出來:

1. **一張 issue = 一個 session,land 即結束。** 不要有常駐的 FE / BE。冷啟動的成本是讀一份
   brief;常駐的成本是一個長到 120k 的 context 每輪重付。而冷啟動買到的東西,正好是本 skill
   最在乎的:**一雙沒被前幾輪污染的眼睛**——`[circular-expectation]` 在同一個 session 待久了
   就是那樣長出來的。

2. **orchestrator 是路由器,不是讀者。** 跑測試、讀 diff、掃 log 這種吃 context 的活,丟進
   子 agent 或抽離 worktree,只回傳**判決 + 數字**。第三節對 peer 要求的五行 handover,
   對你自己的驗收同樣適用——不要自己看全文,然後讓全文永久駐留。

3. **原始輸出先落檔,讀進 context 的要是答案。**

   ```bash
   npm test > /tmp/t.log 2>&1; echo "exit=$?"; tail -5 /tmp/t.log
   ```

   先存檔再取 `$?`,不是 pipe 到 tail(`[pipe-eats-exit-code]`)。要看 diff 就 `--stat`,
   要看 log 就 grep 你要的那一行。

4. **可證偽的驗收條件:一個冷 session 能不能只靠痕跡接手?** 不能的話,不是 session 的問題,
   是**交付格式漏了東西**——去補格式,不要去養一個活很久的 session。

5. **skill 自己也在預算裡。** 本檔常駐,失敗目錄按需讀。每一個 peer session 都會載入同一份,
   所以這裡每多 1KB,要乘以同時開的 session 數。

### 常駐 session 只在三個前提都成立時開

子 agent(用完即丟、自己的 worktree)是預設。常駐的 FE / BE session 一天之內出過兩次事故:
一個做到一半安靜下來,沒有人知道它在等什麼;一個 cwd 在主 checkout,跑了 `git checkout <tree> -- .`,
owner 的工作樹被改掉而沒有任何通知。開之前三個前提:

1. **它有自己的 worktree,而且 cwd 在那裡**——不是主 checkout、不是別人的目錄。
2. **它的 brief 完整到能冷啟動**——五塊 + 三欄授權 + 交付格式,全部在第一則訊息;去程只有一次。
3. **owner 知道它存在、知道它在做哪張 issue**——orchestrator 在 issue 留言記下「session 名稱 / worktree /
   派工時間」,不然它安靜的時候沒有人分得出「做完在等」還是「壞了」。

判準:三個裡少一個,就用子 agent。它安靜超過一個回合,先看 `isRunning` 和它 worktree 的 `git status`,
再決定戳它或收回重派——不要直接往 owner 報「它停擺了」(`[diagnosis-outlives-validity]`)。

### 判準

- 你正在對一個 session 說「你還記得剛才……」——停下來。它記得的那件事應該在 issue 上。
- 你正在 cat 一份超過一百行的輸出——先問這一百行裡你要的是哪一個數字。
- 你在同一個 session 裡 land 了第三張 issue——前兩張的 context 還在付費,而且在污染第三張的眼睛。
- 你開了一個常駐 session,cwd 是主 checkout——它會在那裡 `git checkout <tree> -- .`,owner 的工作樹就變了,而沒有人會通知 owner。每個 session 開在自己的 worktree。
- 你開了一個 peer,只因為「看起來可以平行」——回到開頭那一句:每個 session 都是冷啟動,
  只有能獨立做到「可交付」的線才值得分出去。

---

## 十二、新專案起手:數字 → 契約 → 機械 → 一條紅過的 guard → 才開團隊

> 2026-09-07,來自一輪實戰(elevator_inc #135 / #136)。每一步的順序都是付過學費的;
> 每一步有「做完的判準」,沒到就不要往下。runbook 版在 obsidian/Notes/agent team delivery runbook.md。

頭幾天所有東西互相耦合,一個 session 就好——開頭那句「不要為了平行而平行」在新專案最容易被違反。

### Phase 0:一個普通 session,目標只有「讓可驗證存在」

0. **repo 骨架**:`git init`、`gh repo create`、第一個 commit、`.gitignore`。
1. **設計文件要有數字**:每個機制旁邊寫起始值、上限、公式、門檻。
   判準:harness 的 `SPEC` 常數可以逐條從這裡抄。抄不出數字的機制,還不能派工。
2. **`/agent-team-delivery init <repo>`**:放進 `TEAM.md`、`tools/orch.sh`、`tools/serve.py`、`tests/`。
   然後 **owner 填所有權表**——只有一個人也要填(寫「暫時全部 BE」也行),每個檔案一列。
   起手的 session 可以起草、由 owner 逐列確認:**確認過的草稿等於 owner 填的**(initialize_a_game 就這樣做),
   沒確認過的列不算。
   判準:`orch wt smoke HEAD && orch rm smoke` 走得通;所有權表沒有空格。子 agent **不會載入 skill**,
   peer 要遵守的規矩只能在 repo 裡。
3. **第一條 guard 是產品的動詞**(`[product-verb]`):第 0 組常數對照,第 1 組「動詞停擺會紅」,門檻鬆、抓崩塌。
   然後**讓它紅一次**:`orch falsify` → `orch serve` → `?json=1` 看它紅、看它印什麼 → `orch restore` → `orch clean`。
   判準:harness 綠,而且 owner 親眼看過它紅(把紅的那一行、或頁面截圖交到 owner 面前,也算)。
4. **commit。** 到這裡有:數字、契約、機械、一條紅過的 guard。**沒有 harness 之前不要派工**——派了也驗不了。

### Phase 1:開 orchestrator,一個 peer 走完整圈

5. **開 orchestrator session**(標題「<專案> orchestrator」)。cwd **必須**在這個 repo 裡(主 checkout,或它的一個
   worktree;桌面 app 用 task chip 開的 session 就是後者)——子 agent 的
   worktree 是從主 session 的工作目錄開的(§十三),開在 vault 裡 peer 拿到的就是 vault。它在主 checkout **只讀**
   (`git fetch`、`gh`、開 worktree),所有改動在 `_wt/` 與子 agent 自己的 worktree。開場:
   > 你是這個專案的 orchestrator,照 agent-team-delivery skill 和 repo 的 TEAM.md 做。目標:__。優先序:__。
   > 你開 issue、寫 brief、派子 agent、獨立驗證、land;你不寫產品程式碼。要 owner 裁決的事在 issue 留言標
   > 「要 owner 裁決」,我在 issue 上回。先做一張 issue、走完派 → 交付 → 驗 → land,再跟我報告。
6. **它開第一張 issue**。owner 看的是:裁決 + 理由、約束 + 後果、不做什麼、**證偽案例**、三欄授權。
   判準:證偽案例寫得出「錯誤的實作會在哪裡被咬」。寫不出來 → 它還不懂這張,退回 orchestrator,不是退回 peer。
7. **它派一個子 agent、驗、land**。owner 這一輪只做一件事:在 issue 上回裁決。不跟 peer 講話、不進 `_wt/`、
   不在主 checkout 動手。判準:land 報告有五行 handover、harness 前後數字、一次證偽、merge 的 SHA 與父節點。

### Phase 2:平行

8. 兩條線互不相依時開兩個子 agent;動同一張資料表的,brief 要求先列 id。
9. 只有 owner 想中途看、中途改時才開常駐 session,§十一 的三個前提缺一不可。

### 持續維護

- 每輪結束問一次「**這一輪儀器有沒有騙我?**」有 → 失敗目錄(全域 skill),不是 TEAM.md。
- 所有權、慣例變了 → `TEAM.md`,orchestrator 裁決、commit message 寫理由。
- owner 發現自己在跟 peer 講話、或在主 checkout 改東西 → 流程漏了,回 TEAM.md 補規則。

樣板在 `references/starter/`。skill 留判斷力,契約和機械跟著 repo 走。

### `/agent-team-delivery init <repo 路徑>`

這是本 skill **唯一會寫進 repo** 的動作,而且只寫樣板、不 commit:

1. 把 `references/starter/` 複製進去:`TEAM.md`、`tools/orch.sh`、`tools/serve.py`、`tools/check_public_imports.mjs`、
   `tests/harness.js`、`tests/index.html`、`tests/acc_modules.js`(把裡面的 `SHIP` 改成這個專案出貨的資料夾)。
   **已存在的檔案不覆蓋**,列出來讓 owner 決定。
2. `.gitignore` 加 `__MARKER_ORCH.txt`、`__orch_*` 與 `.claude/worktrees/`(子 agent 的 worktree 開在那裡,§十三)(已有就不重複)。
3. `bash tools/orch.sh` 印得出用法、`bash tools/orch.sh wt smoke HEAD && bash tools/orch.sh rm smoke` 走得通,才算裝好。
   `~/.claude/agents/` 裡要有 §十三 的六個 agent;沒有就跑 `bash ~/.claude/skills/setup/install.sh`。Agent 工具的清單裡看不到它們時,再請 owner 重開 session。
4. 停在這裡:**所有權表與 commit 是 owner 的決定**。owner 已經逐列確認過草稿(例如 initialize_a_game 的第一次
   go)→ 照確認的內容寫入並 commit,commit message 記「所有權表 owner 確認,<日期>」;沒有確認 → 把「還缺什麼」
   列給 owner,不要替他填。

---

## 十三、派子 agent 的機械:角色 → agent → 模型

> 草稿(2026-09-18)。來自 zongheng:一個專案從起手的 session 一路寫到上線,orchestrator 從沒出現——
> 沒有人說出觸發詞,起手的 skill 停在「等 owner 說 go」之後就沒有下文。所有程式碼都是同一個 session
> 寫、同一個 session 驗的(§一的「自己驗自己」)。這一節補三件事:誰來派、派給誰、用哪個模型。
> 還沒實戰過,踩到反例就改。

### 誰來派

主 session 就是 orchestrator,**而且它必須開在遊戲的 repo 裡**:子 agent 的 worktree 是從主 session 的
工作目錄開的(`.claude/worktrees/<name>/`,分支 `worktree-<name>`,從預設分支長出來)。開在 obsidian
vault 或 scratch 資料夾裡,peer 拿到的就是那裡的 worktree。

「在有 `TEAM.md` 的 repo 裡做實作就派工」由使用者層級的 `~/.claude/CLAUDE.md` 設成預設(原稿在本 repo 的
`setup/CLAUDE.md`),不再靠觸發詞。

### 派給誰:agent 檔

定義在 `references/agents/`,用 repo 根目錄的 `bash setup/install.sh` 裝到 `~/.claude/agents/`(連同
`setup/CLAUDE.md` → `~/.claude/CLAUDE.md`)。改 repo 裡那一份,再跑一次 install;本機被改過的檔案它只印 diff、
不覆蓋。新電腦的步驟在 `setup/README.md`。文件說第一次建立那個
資料夾要重開 session 才會載入;2026-09-18 實測沒重開,幾秒內就出現在 Agent 工具的清單裡。清單裡看不到才重開。

每一個都寫死了模型、effort、`isolation: worktree`(cwd 就是它自己的 worktree,碰不到主 checkout),
以及 `omitClaudeMd: true`:peer 的規矩只在 `TEAM.md` 和 brief,給 orchestrator 的 CLAUDE.md
(「你不寫產品程式碼」)不能混進 peer 的 context。

| 角色 | agent | 模型 | effort | 為什麼 |
|---|---|---|---|---|
| orchestrator | 主 session | Opus 5;判斷最重的輪次用 Fable 5.1 | owner 定 | 寫 brief、驗證、land;活得最久,讀判決不讀全文 |
| BE | `peer-be` | opus | high | 引擎、規則、bot、伺服器:錯了看不出來,代價最高 |
| FE | `peer-fe` | sonnet | medium | 頁面與樣式:反覆改、用眼睛驗 |
| writer | `peer-writer` | sonnet | medium | 牌文、規則書、兩種語言的字串 |
| artist | `peer-artist` | sonnet | medium | 寫 prompt、跑 ComfyUI、交 contact sheet |
| 驗證跑腿 | `orch-checker` | sonnet | high | 在指定 SHA 上跑測試與證偽,只回判決 + 數字(§十一第 2 條);只有 Bash / Read / Grep / Glob |
| 機械活 | `peer-chore` | haiku | low | 規格寫死的轉檔、改名、抽資料 |

沒有指定 `subagent_type` 的子 agent(general-purpose)會繼承主 session 的模型——通常是最貴的那一個。

### 怎麼派

```
Agent({ subagent_type: "peer-fe", description: "#12 C2 landing",
        prompt: "<issue 連結 + brief 五塊 + 三欄授權 + 交付格式 + 分支名>" })
```

- 模型跟著 agent 走。**只有 brief 寫得出理由時才加 `model` 覆寫**(例:一張 FE issue 其實在改狀態機 → `opus`)。
- 互不相依的兩條線同時派(子 agent 預設在背景跑,做完會叫醒你);動同一張資料表的,brief 先要 id(§一)。
- **退回用 `SendMessage` 接同一個 agent**,它的 context 還在;開一個新的 agent 等於開新 issue(四之 4.6)。
- 同一張 issue 退回兩次還沒過:先問 brief 是不是缺了什麼。brief 沒問題,才換高一級的模型重派
  (haiku → sonnet → opus → fable),並在 issue 留言寫為什麼換。
- 驗證的判斷不外包。`orch-checker` 替你讀儀器;看畫面、讀紅的理由、決定 land 的是你。
- 有改動的 worktree 不會自動刪:land 之後把 `.claude/worktrees/` 底下那一個清掉,`orch rm` 驗證用的 `_wt/`,
  再 `git worktree prune`。不收的話一個專案做完會留下十幾棵樹,`git worktree list` 讀不完,
  也分不出哪一棵還有人在用。

### 判準

- 你正要在主 session 裡 Edit 一個產品檔案——停,那是一張 issue。例外只有 owner 明講要你親手改,
  而你在 issue 上記下「沒有經過獨立驗證」。
- 你派出去的 agent 跟你用同一個模型,brief 裡卻沒寫為什麼——多半是忘了 `subagent_type`。
- peer 的 worktree 出現在 vault 或別的 repo 底下——主 session 開錯地方了。
- 你把 peer 的 transcript 讀進來了——你要的是五行 handover 和 SHA。


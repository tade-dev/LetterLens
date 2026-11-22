import { fillPrompt } from "../card/defaults.js";
import { showsAmount, extractAmountFigure } from "../card/amount.js";
import { formatIsoDate } from "../card/dates.js";
import { displayTitle, opensScamWarning, senderLabel, type LetterCard } from "../card/schema.js";
import { resolveCardSettings, type CardSettings } from "../card/settings.js";
import { detectDevice, deviceMessage, type DeviceStatus } from "../chrome/device.js";
import {
  asGenerator,
  cloudModel,
  countWithModel,
  downloadDeviceModel,
  initFirebase,
  loadCardSettings,
  onDeviceModel,
  startAppCheck,
  type AppCheckState,
} from "../firebase/client.js";
import { describeRemovals, redact } from "../privacy/redactor.js";
import { requestCard, type AnswerPlace } from "../read/request-card.js";
import { countPromptTokens, exceedsOnDeviceLimit, ON_DEVICE_TOKEN_LIMIT } from "../tokens.js";
import type { FirebaseApp } from "firebase/app";

const bundledSettings = resolveCardSettings({
  prompt: "",
  schemaVersion: 0,
  cardModel: "",
  fallbackModel: "",
});

export function mount(root: HTMLElement): void {
  const shell = buildShell();
  root.append(shell.skip, shell.header, shell.main, shell.footer, shell.dialog);

  let device: DeviceStatus = { browser: "other", promptApi: false, availability: "missing" };
  let settings: CardSettings = bundledSettings;
  let firebase: FirebaseApp | null = null;
  let appCheck: AppCheckState = { ready: false, note: "" };
  let busy = false;
  let cloudOffered = false;

  const letter = (): string => shell.letter.value.trim();

  const sync = () => {
    const hasLetter = letter().length > 0;
    const onDeviceReady = device.browser === "chrome" && device.promptApi && device.availability === "available";
    const needsDownload = device.availability === "downloadable" || device.availability === "downloading";
    shell.readiness.textContent = deviceMessage(device);
    // Green is only ever "where it was read", so the badge claims Chrome
    // on-device reading only when that is actually available.
    if (onDeviceReady) {
      shell.chromeBadge.textContent = "Reading in Chrome on this computer";
      shell.chromeBadge.classList.remove("chrome-badge-off");
    } else {
      shell.chromeBadge.textContent = "On-device reading is not available here";
      shell.chromeBadge.classList.add("chrome-badge-off");
    }
    shell.download.hidden = !needsDownload || !firebase;
    shell.download.disabled = busy;
    shell.read.disabled = busy || !firebase || !onDeviceReady || !hasLetter;
    shell.cloud.hidden = !firebase || !hasLetter || (onDeviceReady && !cloudOffered);
    shell.cloud.disabled = busy;
    shell.promptSource.textContent = promptSourceLine(settings, firebase);
  };

  const setBusy = (next: boolean) => {
    busy = next;
    shell.form.setAttribute("aria-busy", next ? "true" : "false");
    sync();
  };

  const clearAlert = () => {
    shell.alert.hidden = true;
    shell.alert.textContent = "";
  };

  const showAlert = (message: string) => {
    shell.alert.hidden = false;
    shell.alert.textContent = message;
  };

  const setProgress = (message: string, fraction?: number, title = "Reading your letter…") => {
    shell.progress.hidden = false;
    shell.progressTitle.textContent = title;
    shell.progressText.textContent = message;
    shell.bar.hidden = fraction === undefined;
    if (fraction === undefined) {
      shell.bar.removeAttribute("value");
    } else {
      shell.bar.max = 1;
      shell.bar.value = Math.max(0, Math.min(1, fraction));
    }
  };

  const clearProgress = () => {
    shell.bar.hidden = true;
    shell.progress.hidden = true;
    shell.progressText.textContent = "";
    shell.bar.removeAttribute("value");
  };

  const clearCard = () => {
    shell.card.hidden = true;
    shell.card.replaceChildren();
  };

  shell.letter.addEventListener("input", () => {
    cloudOffered = false;
    clearAlert();
    clearCard();
    sync();
  });

  // Dragging a file anywhere over the zone highlights it. dragleave fires when
  // the pointer crosses a child, so the counter stops it flickering.
  let dragDepth = 0;
  const setDragging = (on: boolean) => {
    shell.fileLabel.classList.toggle("is-dragging", on);
  };
  shell.fileLabel.addEventListener("dragenter", (event) => {
    event.preventDefault();
    dragDepth += 1;
    setDragging(true);
  });
  shell.fileLabel.addEventListener("dragover", (event) => {
    event.preventDefault();
  });
  shell.fileLabel.addEventListener("dragleave", () => {
    dragDepth = Math.max(0, dragDepth - 1);
    if (dragDepth === 0) setDragging(false);
  });
  shell.fileLabel.addEventListener("drop", (event) => {
    event.preventDefault();
    dragDepth = 0;
    setDragging(false);
    const dropped = event.dataTransfer?.files?.[0];
    if (dropped) loadFile(dropped);
  });

  shell.file.addEventListener("change", () => {
    const file = shell.file.files?.[0];
    shell.file.value = "";
    if (!file) return;
    loadFile(file);
  });

  function loadFile(file: File): void {
    void readTxt(file)
      .then((text) => {
        shell.letter.value = text;
        shell.letter.dispatchEvent(new Event("input"));
        shell.fileStatus.textContent = `Loaded ${file.name}. The text is in the box above. It is not stored.`;
      })
      .catch((error: unknown) => {
        shell.fileStatus.textContent = "";
        showAlert(error instanceof Error ? error.message : "That file could not be read.");
      });
  }

  shell.form.addEventListener("submit", (event) => {
    event.preventDefault();
    void runOnDevice();
  });

  shell.cloud.addEventListener("click", () => {
    void runCloud();
  });

  shell.download.addEventListener("click", () => {
    void runDownload();
  });

  void (async () => {
    device = await detectDevice();
    firebase = initFirebase();
    if (!firebase) {
      showAlert(
        "Add your Firebase web config in web/app/.env.local, using .env.example as the list of names, then restart npm run dev. No letter is sent until that is set.",
      );
      sync();
      return;
    }
    appCheck = startAppCheck(firebase);
    shell.appCheck.textContent = appCheck.note;
    sync();
    try {
      settings = await loadCardSettings(firebase);
    } catch {
      settings = bundledSettings;
    }
    sync();
  })();

  async function runDownload(): Promise<void> {
    if (!firebase || busy) return;
    clearAlert();
    setBusy(true);
    setProgress(
      "Downloading the on-device model. This can take several minutes.",
      0,
      "Getting ready…",
    );
    try {
      const model = onDeviceModel(firebase, settings.cardModel);
      await downloadDeviceModel(model, (fraction) => {
        const value = fraction <= 1 ? fraction : fraction / 100;
        setProgress(
          `Downloading the on-device model. ${formatPercent(value)} complete.`,
          value,
          "Getting ready…",
        );
      });
      device = await detectDevice();
      clearProgress();
      if (device.availability === "available") {
        shell.fileStatus.textContent = "The on-device model is ready.";
      } else {
        showAlert("The download finished, but the on-device model is still not ready.");
      }
    } catch {
      clearProgress();
      showAlert("The on-device model could not be downloaded. Nothing was sent.");
    } finally {
      setBusy(false);
    }
  }

  async function runOnDevice(): Promise<void> {
    if (!firebase || busy) return;
    const text = letter();
    if (!text) return;
    if (!(device.browser === "chrome" && device.promptApi && device.availability === "available")) {
      cloudOffered = true;
      showAlert(`${deviceMessage(device)} Nothing has been sent.`);
      sync();
      return;
    }
    clearAlert();
    clearCard();
    setBusy(true);
    setProgress("Checking the length of this letter.");
    try {
      const prompt = fillPrompt(settings.prompt, text);
      const model = onDeviceModel(firebase, settings.cardModel);
      const counted = await countPromptTokens(prompt, (value) => countWithModel(model, value));
      if (exceedsOnDeviceLimit(counted.tokens)) {
        cloudOffered = true;
        clearProgress();
        showAlert(tooLongMessage(counted.tokens, counted.method));
        sync();
        return;
      }
      setProgress("Nothing has left your computer.", undefined, "Reading on this device…");
      const result = await requestCard({
        generator: asGenerator(model),
        prompt,
        letter: text,
        expected: "on_device",
      });
      clearProgress();
      if (!result.ok) {
        cloudOffered = true;
        showAlert(`${failureMessage(result.code, result.message)} Nothing was sent.`);
        sync();
        return;
      }
      renderCard(shell.card, result.card, result.place, null);
    } catch {
      clearProgress();
      cloudOffered = true;
      showAlert("The on-device read stopped before a card was ready. Nothing was sent.");
      sync();
    } finally {
      setBusy(false);
    }
  }

  async function runCloud(): Promise<void> {
    if (!firebase || busy) return;
    const text = letter();
    if (!text) return;
    clearAlert();
    shell.cloud.disabled = true;
    shell.read.disabled = true;
    const redaction = redact(text);
    const prompt = fillPrompt(settings.prompt, redaction.text);
    const allowed = await confirmSend(shell, {
      summary: describeRemovals(redaction),
      text: prompt,
      canSend: appCheck.ready,
      blocked: appCheck.ready ? "" : appCheck.note,
    });
    if (!allowed) {
      showAlert("Nothing was sent.");
      sync();
      return;
    }
    setBusy(true);
    clearCard();
    setProgress("Only the redacted text was sent.", undefined, "Reading in the cloud…");
    try {
      let modelUsed = settings.cardModel;
      let result = await requestCard({
        generator: asGenerator(cloudModel(firebase, modelUsed)),
        prompt,
        letter: text,
        expected: "in_cloud",
        redactionMap: redaction.map,
      });
      const fallback = settings.fallbackModel;
      if (
        !result.ok &&
        result.code === "model-error" &&
        result.retryable &&
        fallback &&
        fallback !== modelUsed
      ) {
        modelUsed = fallback;
        setProgress(
          "The first model was busy. Trying the fallback with the same redacted text.",
          undefined,
          "Reading in the cloud…",
        );
        result = await requestCard({
          generator: asGenerator(cloudModel(firebase, modelUsed)),
          prompt,
          letter: text,
          expected: "in_cloud",
          redactionMap: redaction.map,
        });
      }
      clearProgress();
      if (!result.ok) {
        showAlert(failureMessage(result.code, result.message));
        return;
      }
      renderCard(shell.card, result.card, result.place, result.place === "in_cloud" ? modelUsed : null);
    } catch {
      clearProgress();
      showAlert("The cloud read stopped before a card was ready.");
    } finally {
      setBusy(false);
    }
  }
}

function tooLongMessage(tokens: number, method: "countTokens" | "estimate"): string {
  const how = method === "countTokens" ? "The on-device model counted" : "A conservative estimate is";
  return `${how} ${tokens.toLocaleString("en-GB")} tokens. The on-device limit is ${ON_DEVICE_TOKEN_LIMIT.toLocaleString("en-GB")}. Nothing was sent. You can review a redacted copy and send that instead.`;
}

function failureMessage(code: string, message: string): string {
  if (code === "left-device") {
    return "The on-device request was answered in the cloud before you agreed to send anything. That answer was discarded.";
  }
  if (code === "invalid") return `The model did not return a valid card. ${message}`;
  return message;
}

function promptSourceLine(settings: CardSettings, firebase: FirebaseApp | null): string {
  if (!firebase) return "Card prompt: built-in schema 2. Firebase is not configured yet.";
  if (settings.promptSource === "remote") return "Card prompt: Remote Config schema 2.";
  return "Card prompt: built-in schema 2. Remote Config is not publishing schema 2 yet, so the built-in prompt is used.";
}

function formatPercent(fraction: number): string {
  return `${Math.round(fraction * 1000) / 10}%`;
}

function confirmSend(
  shell: Shell,
  input: { summary: string; text: string; canSend: boolean; blocked: string },
): Promise<boolean> {
  shell.consentSummary.textContent = input.summary;
  shell.consentText.textContent = input.text;
  shell.consentBlock.hidden = input.canSend;
  shell.consentBlock.textContent = input.blocked;
  shell.consentSend.disabled = !input.canSend;
  return new Promise((resolve) => {
    const finish = () => {
      shell.dialog.removeEventListener("close", finish);
      resolve(shell.dialog.returnValue === "send");
    };
    shell.dialog.addEventListener("close", finish);
    shell.dialog.showModal();
    shell.consentText.focus();
  });
}

/** Numbers the card's blocks so each one rises just after the last. */
function stagger(host: HTMLElement): void {
  let index = 0;
  for (const child of host.children) {
    (child as HTMLElement).style.setProperty("--i", String(index));
    index += 1;
  }
}

function renderCard(host: HTMLElement, card: LetterCard, place: AnswerPlace, modelName: string | null): void {
  host.hidden = false;
  host.replaceChildren();
  const badge = el("p", { className: place === "on_device" ? "badge badge-device" : "badge badge-cloud" });
  badge.textContent = place === "on_device" ? "Read on this device" : "Read in the cloud";
  const title = el("h2");
  title.tabIndex = -1;
  title.textContent = displayTitle(card);
  host.append(badge, title);

  // A letter with quoted scam signs never shows its own instruction as the thing
  // to do: that would tell the reader to pay the fee or follow the link. iOS
  // pushes ScamWarningScreen for exactly this reason and never renders the action.
  const isScam = opensScamWarning(card);

  if (isScam) {
    const warning = el("p", { className: "alert" });
    warning.textContent = "This letter has signs of a scam";
    const caveat = el("p", { className: "note" });
    caveat.textContent =
      "We can't be sure. Check with the sender using contact details you find yourself.";
    host.append(warning, caveat);
    host.append(
      section(
        "Stop before you pay or click",
        `Do not use the links, phone numbers or payment details in this letter. Look up ${senderLabel(card)} yourself and check with them.`,
      ),
    );
    host.append(section("What it claims to be", card.action || "The letter does not say."));
  } else {
    if (card.noActionNeeded) {
      const note = el("p", { className: "note" });
      note.textContent = "This letter does not ask you to do anything.";
      host.append(note);
    }
    host.append(section("What you need to do", card.action || "The letter does not say."));
  }

  const amount = amountRow(card);
  if (amount) host.append(amount);

  const deadline = el("section", { className: "fact" });
  deadline.append(heading("Deadline"));
  if (card.deadline && card.deadlineQuote) {
    const when = el("p", { className: "deadline" });
    when.textContent = formatIsoDate(card.deadline);
    const quote = el("blockquote");
    quote.textContent = card.deadlineQuote;
    deadline.append(when, quote);
  } else {
    const none = el("p");
    none.textContent = "No deadline found in the letter.";
    deadline.append(none);
  }
  host.append(deadline);

  if (card.watchOuts.length > 0) {
    const watch = el("section");
    watch.append(heading("Worth knowing"));
    watch.append(list(card.watchOuts));
    host.append(watch);
  }

  const signs = el("section");
  signs.append(heading("Signs to check"));
  if (isScam) {
    const how = el("p", { className: "note" });
    how.textContent = `How to check with ${senderLabel(card)}: find their number on their own website, not in this letter. We never say a letter is safe. Only the sender can confirm.`;
    signs.append(how);
  }
  if (card.scamSigns.length === 0) {
    const none = el("p");
    none.textContent = "No signs to check were quoted from this letter.";
    signs.append(none);
  } else {
    const items = el("ul");
    for (const sign of card.scamSigns) {
      const item = el("li");
      const label = el("p");
      label.textContent = sign.sign;
      item.append(label);
      if (sign.quote) {
        const quote = el("blockquote");
        quote.textContent = sign.quote;
        item.append(quote);
      }
      items.append(item);
    }
    signs.append(items);
  }
  host.append(signs);

  const meta = el("p", { className: "meta" });
  meta.textContent = modelName
    ? `Card schema version 2. Cloud model: ${modelName}.`
    : "Card schema version 2.";
  host.append(meta);
  stagger(host);
  title.focus();
}

function amountRow(card: LetterCard): HTMLElement | null {
  if (!showsAmount(card.type)) return null;
  const quote = card.amountQuote;
  const figure = quote ? extractAmountFigure(quote) : null;
  if (quote && figure) {
    return amountBlock(
      `Amount, ${figure}. From the letter: ${quote}.`,
      el("p", { className: "amount-label" }, "AMOUNT"),
      el("p", { className: "amount-figure" }, figure),
      el("hr", { className: "amount-rule" }),
      el("p", { className: "amount-caption" }, `From the letter: “${quote}”`),
    );
  }
  if (quote) {
    return amountBlock(
      `Amount. From the letter: ${quote}.`,
      el("p", { className: "amount-label" }, "AMOUNT"),
      el("p", { className: "amount-quote" }, `“${quote}”`),
      el("p", { className: "amount-caption" }, "From the letter. Check it for the exact total."),
    );
  }
  return amountBlock(
    "No amount found in this letter. Check the letter for how much to pay.",
    el("p", { className: "amount-label" }, "AMOUNT"),
    el("p", { className: "amount-missing" }, "No amount found in this letter."),
    el("p", { className: "amount-sub" }, "Check the letter for how much to pay."),
  );
}

function amountBlock(label: string, ...visual: HTMLElement[]): HTMLElement {
  const block = el("section", { className: "fact amount" });
  block.setAttribute("role", "group");
  block.setAttribute("aria-label", label);
  const shown = el("div");
  shown.setAttribute("aria-hidden", "true");
  shown.append(...visual);
  block.append(shown);
  return block;
}

function section(label: string, text: string): HTMLElement {
  const block = el("section");
  const paragraph = el("p");
  paragraph.textContent = text;
  block.append(heading(label), paragraph);
  return block;
}

function heading(text: string): HTMLElement {
  const node = el("h3");
  node.textContent = text;
  return node;
}

function list(items: string[]): HTMLElement {
  const node = el("ul");
  for (const item of items) {
    const line = el("li");
    line.textContent = item;
    node.append(line);
  }
  return node;
}

async function readTxt(file: File): Promise<string> {
  const name = file.name.toLowerCase();
  if (!name.endsWith(".txt") && file.type !== "text/plain") {
    throw new Error("Upload a .txt file. Photos and PDFs are not read in this version.");
  }
  if (file.size > 1_000_000) throw new Error("That file is too large. Try a shorter .txt file.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.includes(0)) throw new Error("That file does not look like plain text.");
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    throw new Error("That file is not UTF-8 text.");
  }
}

interface Shell {
  skip: HTMLElement;
  header: HTMLElement;
  main: HTMLElement;
  footer: HTMLElement;
  dialog: HTMLDialogElement;
  form: HTMLFormElement;
  letter: HTMLTextAreaElement;
  file: HTMLInputElement;
  fileStatus: HTMLElement;
  readiness: HTMLElement;
  chromeBadge: HTMLElement;
  fileLabel: HTMLLabelElement;
  download: HTMLButtonElement;
  read: HTMLButtonElement;
  cloud: HTMLButtonElement;
  progress: HTMLElement;
  bar: HTMLProgressElement;
  progressText: HTMLElement;
  progressTitle: HTMLElement;
  alert: HTMLElement;
  card: HTMLElement;
  promptSource: HTMLElement;
  appCheck: HTMLElement;
  consentSummary: HTMLElement;
  consentText: HTMLElement;
  consentBlock: HTMLElement;
  consentSend: HTMLButtonElement;
}

function buildShell(): Shell {
  const skip = el("a", { className: "skip", href: "#letter" });
  skip.textContent = "Skip to the letter";

  // Header is screen 11: logo lockup left, "where it was read" badge right.
  const header = el("header", { className: "mast" });
  const lockup = el("div", { className: "lockup" });
  lockup.insertAdjacentHTML("afterbegin", LOGO_SVG);
  const mark = el("p", { className: "mark" });
  mark.textContent = "LetterLens";
  lockup.append(mark);
  const chromeBadge = el("p", { className: "chrome-badge" });
  chromeBadge.textContent = "Checking this browser";
  header.append(lockup, chromeBadge);

  const intro = el("div", { className: "intro" });
  const title = el("h1");
  title.textContent = "Drop in a letter. Get the short version.";
  const lede = el("p", { className: "lede" });
  lede.textContent =
    "Gemini Nano reads it inside your browser. Nothing is uploaded unless you ask.";
  intro.append(title, lede);

  const main = el("main");
  const readiness = el("p", { className: "readiness", role: "status" });
  readiness.textContent = "Checking whether this browser can read on device.";
  const how = el("section", { className: "how", "aria-labelledby": "how-title" });
  const howTitle = el("h2", { id: "how-title" });
  howTitle.textContent = "How a letter is read";
  const howList = el("ol");
  for (const step of [
    "On this device first. In Google Chrome, Firebase AI Logic asks the on-device model. The letter is not uploaded.",
    "If that cannot run, or the on-device read fails, you can review a redacted copy. Names, addresses, postcodes, account and reference numbers, National Insurance numbers, NHS numbers, phone numbers, and email addresses are removed.",
    "You see the exact text. Nothing is sent until you choose Send this text.",
    "The card says where the answer actually came from: on this device, or in the cloud.",
  ]) {
    const item = el("li");
    item.textContent = step;
    howList.append(item);
  }
  how.append(howTitle, howList);

  const form = document.createElement("form");
  const letterLabel = el("label", { for: "letter" });
  letterLabel.textContent = "Letter text";
  const letter = document.createElement("textarea");
  letter.id = "letter";
  letter.name = "letter";
  letter.required = true;
  letter.rows = 9;
  letter.spellcheck = true;
  letter.autocomplete = "off";
  letter.setAttribute("aria-describedby", "letter-help");
  const help = el("p", { id: "letter-help", className: "help" });
  help.textContent = "Paste the letter, or upload a .txt file. The text stays in this page until you agree to a cloud read.";
  // The browser's own file control is the one piece of unstyled chrome on the
  // page. The input stays in the DOM for the keyboard and for assistive tech;
  // the label is what anyone sees, and it doubles as a drop target.
  const fileLabel = document.createElement("label");
  fileLabel.className = "dropzone";
  fileLabel.htmlFor = "letter-file";
  fileLabel.insertAdjacentHTML("afterbegin", UPLOAD_SVG);
  const dropTitle = el("span", { className: "dropzone-title" });
  dropTitle.textContent = "Drop a .txt file here";
  const dropHint = el("span", { className: "dropzone-hint" });
  dropHint.textContent = "or click to choose a file";
  const file = document.createElement("input");
  file.type = "file";
  file.accept = ".txt,text/plain";
  file.id = "letter-file";
  file.className = "dropzone-input";
  fileLabel.append(dropTitle, dropHint, file);
  const fileStatus = el("p", { className: "help", role: "status" });

  const actions = el("div", { className: "actions" });
  const download = button("download", "Download the on-device model", "button");
  const read = button("read", "Read on this device", "submit");
  const cloud = button("cloud", "Review a redacted copy", "button");
  read.disabled = true;
  cloud.hidden = true;
  download.hidden = true;
  actions.append(download, read, cloud);
  form.append(letterLabel, letter, help, fileLabel, fileStatus, actions);

  // The reading state borrows the scan line from iOS's screen 04. It carries no
  // claim about how far along the read is: the browser read is one await with no
  // steps to report, so a ticking checklist here would be invented progress.
  // The determinate bar appears only for the model download, which has a real
  // fraction to show.
  const progress = el("div", { className: "progress", hidden: "true" });
  const sweep = el("div", { className: "sweep", "aria-hidden": "true" });
  sweep.append(el("span", { className: "sweep-line" }));
  const progressTitle = el("p", { className: "progress-title" });
  progressTitle.textContent = "Reading your letter…";
  const progressText = el("p", { role: "status" });
  const bar = document.createElement("progress");
  bar.max = 1;
  bar.hidden = true;
  bar.setAttribute("aria-label", "Download progress");
  progress.append(sweep, progressTitle, progressText, bar);

  const alert = el("p", { className: "alert", role: "alert", hidden: "true" });
  const card = el("article", { className: "card", hidden: "true", "aria-live": "polite" });
  const appCheck = el("p", { className: "help" });
  // Intake on the left, the card on the right, as in design/html/11-Web.html.
  const columns = el("div", { className: "columns" });
  const intake = el("div", { className: "intake" });
  intake.append(intro, readiness, form, progress, alert);
  const output = el("div", { className: "output" });
  output.append(card, how, appCheck);
  columns.append(intake, output);
  main.append(columns);

  const footer = el("footer");
  const promptSource = el("p");
  const honesty = el("p");
  honesty.textContent = "Explains letters. Not legal or financial advice.";
  footer.append(promptSource, honesty);

  const dialog = document.createElement("dialog");
  dialog.setAttribute("aria-labelledby", "consent-title");
  const consentForm = document.createElement("form");
  consentForm.method = "dialog";
  const consentTitle = el("h2", { id: "consent-title" });
  consentTitle.textContent = "Send this redacted text?";
  const consentSummary = el("p");
  const consentExplain = el("p");
  consentExplain.textContent =
    "This is the exact text that will be sent. If the first answer is not a valid card, the same text is sent once more with a short note to reply in JSON only. If that model is busy, the same text may be sent once to the fallback model. Nothing is sent until you choose Send this text.";
  const consentText = el("pre", { tabindex: "0", "aria-label": "Exact text that will be sent" });
  const consentBlock = el("p", { className: "alert", hidden: "true" });
  const consentActions = el("div", { className: "actions" });
  const consentCancel = button("consent-cancel", "Don't send", "submit");
  consentCancel.value = "cancel";
  const consentSend = button("consent-send", "Send this text", "submit");
  consentSend.value = "send";
  consentActions.append(consentCancel, consentSend);
  consentForm.append(consentTitle, consentSummary, consentExplain, consentText, consentBlock, consentActions);
  dialog.append(consentForm);

  return {
    skip,
    header,
    main,
    footer,
    dialog,
    form,
    letter,
    file,
    fileStatus,
    readiness,
    chromeBadge,
    fileLabel,
    download,
    read,
    cloud,
    progress,
    bar,
    progressText,
    progressTitle,
    alert,
    card,
    promptSource,
    appCheck,
    consentSummary,
    consentText,
    consentBlock,
    consentSend,
  };
}

function button(id: string, label: string, type: "button" | "submit"): HTMLButtonElement {
  const node = document.createElement("button");
  node.id = id;
  node.type = type;
  node.textContent = label;
  return node;
}

function el(tag: string, attrs: Record<string, string> = {}, text?: string): HTMLElement {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "className") node.className = value;
    else if (key === "hidden") node.hidden = value === "true";
    else node.setAttribute(key, value);
  }
  if (text !== undefined) node.textContent = text;
  return node;
}

/** Brand mark from design/logo.svg: ink tile, white envelope, green lens. */
const LOGO_SVG = `<svg width="36" height="36" viewBox="0 0 48 48" aria-hidden="true" focusable="false"><rect width="48" height="48" rx="12" fill="#14213D"/><rect x="9" y="14" width="24" height="18" rx="3" fill="none" stroke="#FFFFFF" stroke-width="2.4"/><path d="M9.5 15.5 21 24l11.5-8.5" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linejoin="round"/><circle cx="32" cy="30" r="6.5" fill="#14213D" stroke="#3FC79A" stroke-width="2.6"/><path d="M36.8 34.8 40 38" stroke="#3FC79A" stroke-width="2.8" stroke-linecap="round"/></svg>`;


const UPLOAD_SVG = `<svg class="dropzone-icon" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 14v4a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-4"/></svg>`;

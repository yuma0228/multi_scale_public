document.addEventListener("DOMContentLoaded", () => {
  const toc = document.querySelector("#text-table-of-contents");
  const tocPane = document.querySelector("#table-of-contents");
  if (!toc) return;

  const expandableItems = Array.from(toc.querySelectorAll("li")).filter(
    (item) => item.querySelector(":scope > ul")
  );

  const setExpanded = (item, expanded) => {
    const button = item.querySelector(":scope > .toc-toggle");
    item.classList.toggle("toc-expanded", expanded);
    item.classList.toggle("toc-collapsed", !expanded);
    button.setAttribute("aria-expanded", String(expanded));
    button.setAttribute(
      "aria-label",
      expanded ? "下位項目を閉じる" : "下位項目を開く"
    );
  };

  expandableItems.forEach((item) => {
    item.classList.add("toc-has-children");

    const button = document.createElement("button");
    button.type = "button";
    button.className = "toc-toggle";
    item.prepend(button);
    setExpanded(item, false);

    button.addEventListener("click", () => {
      setExpanded(item, !item.classList.contains("toc-expanded"));
    });
  });

  const entries = Array.from(toc.querySelectorAll("a[href^='#']"))
    .map((link) => ({
      link,
      heading: document.getElementById(
        decodeURIComponent(link.getAttribute("href").slice(1))
      ),
    }))
    .filter((entry) => entry.heading);

  let currentLink = null;

  const activateLink = (link) => {
    if (!link || link === currentLink) return;
    currentLink = link;

    toc.querySelectorAll("li.toc-current").forEach((item) => {
      item.classList.remove("toc-current");
    });

    const currentItem = link.closest("li");
    currentItem.classList.add("toc-current");

    const activePath = new Set();
    let item = currentItem;
    while (item && toc.contains(item)) {
      activePath.add(item);
      item = item.parentElement.closest("li");
    }

    expandableItems.forEach((expandableItem) => {
      setExpanded(expandableItem, activePath.has(expandableItem));
    });

    if (tocPane) {
      const paneBox = tocPane.getBoundingClientRect();
      const linkBox = link.getBoundingClientRect();
      const topLimit = paneBox.top + 12;
      const bottomLimit = paneBox.bottom - 12;

      if (linkBox.top < topLimit) {
        tocPane.scrollTop -= topLimit - linkBox.top;
      } else if (linkBox.bottom > bottomLimit) {
        tocPane.scrollTop += linkBox.bottom - bottomLimit;
      }
    }
  };

  const syncWithDocumentScroll = () => {
    if (!entries.length) return;

    let activeEntry = entries[0];
    const marker = window.innerHeight * 0.2;

    for (const entry of entries) {
      if (entry.heading.getBoundingClientRect().top <= marker) {
        activeEntry = entry;
      } else {
        break;
      }
    }

    const pageBottom = window.scrollY + window.innerHeight;
    const documentBottom = document.documentElement.scrollHeight;
    if (pageBottom >= documentBottom - 2) {
      activeEntry = entries[entries.length - 1];
    }

    activateLink(activeEntry.link);
  };

  let framePending = false;
  const scheduleSync = () => {
    if (framePending) return;
    framePending = true;
    window.requestAnimationFrame(() => {
      framePending = false;
      syncWithDocumentScroll();
    });
  };

  syncWithDocumentScroll();
  window.addEventListener("scroll", scheduleSync, { passive: true });
  window.addEventListener("resize", scheduleSync);
  window.addEventListener("hashchange", scheduleSync);
});

document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll("#content img").forEach((image) => {
        const existingLink = image.closest("a");
        const link = existingLink || document.createElement("a");
        link.href = image.currentSrc || image.src;
        link.target = "_blank";
        link.rel = "noopener";
        link.classList.add("image-original-link");
        link.title = "原寸画像を新しいタブで開く";

        if (!existingLink) {
            image.parentNode.insertBefore(link, image);
            link.appendChild(image);
        }
    });
});

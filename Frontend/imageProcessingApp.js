const ENV = "default";

const defaultLogic = {
    uploadEndpoint: "/get-upload-url",
    uploadUrlKey: "uploadURL",
    getContentType: (file) => "",
    getImagesEndpoint: "/",
    keys: { url: "Link", date: "Date", filename: "FileName", labels: "Labels" },
    getDeleteEndpoint: (filename) => `/delete?filename=${filename}`
};

const deepseekLogic = {
    uploadEndpoint: "/upload",
    uploadUrlKey: "upload_url",
    getContentType: (file) => file.type,
    getImagesEndpoint: "/images",
    keys: { url: "image_url", date: "upload_time", filename: "filename", labels: "labels" },
    getDeleteEndpoint: (filename) => `/images/${filename}`
};

const geminiLogic = {
    uploadEndpoint: "/presigned-url",
    uploadUrlKey: "upload_url",
    getContentType: (file) => "",
    getImagesEndpoint: "/images",
    keys: { url: "url", date: "upload_time", filename: "filename", labels: "labels" },
    getDeleteEndpoint: (filename) => `/images/${filename}`
};

const config = {
    "default": {
        apiBase: "https://d3145kd4c4.execute-api.us-east-1.amazonaws.com/stage",
        ...defaultLogic
    },
    "default-cf": {
        apiBase: "https://4etpq0i303.execute-api.us-east-1.amazonaws.com/stage",
        ...defaultLogic
    },
    "deepseek": {
        apiBase: "https://t0h5969nr2.execute-api.us-east-1.amazonaws.com/prod",
        ...deepseekLogic
    },
    "deepseek-cf": {
        apiBase: "https://xg0n08lsf0.execute-api.us-east-1.amazonaws.com/prod",
        ...deepseekLogic
    },
    "gemini": {
        apiBase: "https://qntpo19r47.execute-api.us-east-1.amazonaws.com/prod",
        ...geminiLogic
    },
    "gemini-cf": {
        apiBase: "https://443kxm32u9.execute-api.us-east-1.amazonaws.com/prod",
        ...geminiLogic
    }
};

const currentEnv = config[ENV];

const imageInput = document.querySelector("input[type='file']");
const uploadButton = document.getElementById("uploadButton");
const imagesButton = document.getElementById("imagesButton");
const images = document.getElementById('images');

if (uploadButton && imageInput) {
    uploadButton.addEventListener("click", async () => {
        if (!imageInput.files[0]) {
            alert("Select a file first!");
            return;
        }

        const file = imageInput.files[0];
        const api_endpoint = `${currentEnv.apiBase}${currentEnv.uploadEndpoint}`;
        
        try {
            const response = await fetch(`${api_endpoint}?filename=${file.name}`);
            const data = await response.json();

            const uploadUrl = data[currentEnv.uploadUrlKey];

            const uploadResponse = await fetch(uploadUrl, {
                method: "PUT",
                headers: { "Content-Type": currentEnv.getContentType(file) },
                body: file
            });

            if (!uploadResponse.ok) {
                console.error("The S3 didn't accept the file:", uploadResponse.status);
                throw new Error("The S3 didn't accept the file!");
            }

            alert("Upload successful!");
            imageInput.value = "";
        } catch (error) {
            console.error("Upload failed:", error);
        }
    })
}

if (images) {
    async function displayImages() {
        try {
            const response = await fetch(`${currentEnv.apiBase}${currentEnv.getImagesEndpoint}`);
            const data = await response.json();

            data.forEach(image => {
                const card = document.createElement("div");
                card.classList.add("image-card");

                const img = document.createElement("img");
                img.src = image[currentEnv.keys.url];
                img.classList.add("image-img");

                const dateStr = image[currentEnv.keys.date];
                
                const year = dateStr.substring(0, 4);
                const month = dateStr.substring(5, 7);
                const day = dateStr.substring(8, 10);

                let originalHour = parseInt(dateStr.substring(11, 13), 10);
                const minute = dateStr.substring(14, 16);

                let newHour = (originalHour + 2) % 24;

                const formattedHour = String(newHour).padStart(2, '0');

                const time = `${formattedHour}:${minute}`;
                const formattedDate = `${year}. ${month}. ${day}. - ${time}`;

                const info = document.createElement("p");

                const originalFilename = image[currentEnv.keys.filename];
                const displayFilename = originalFilename.replace("resized_", "");
                const labels = image[currentEnv.keys.labels] || "N/A";
                
                info.innerHTML = `<b>Name:</b> ${displayFilename} <br> <b>Labels:</b> ${labels} <br> <b>Date:</b> ${formattedDate}`;
                info.classList.add("image-info");

                const downloadButton = document.createElement("button");
                downloadButton.innerHTML = `<b>Download</b>`;
                downloadButton.classList.add("cardButton");

                downloadButton.onclick = async () => {
                    try {
                        const response = await fetch(image[currentEnv.keys.url]);
                        const blob = await response.blob(); 
                        
                        const blobUrl = URL.createObjectURL(blob);
                        
                        const a = document.createElement("a");
                        a.href = blobUrl;
                        a.download = displayFilename;
                        a.style.display = "none";
                        document.body.appendChild(a);
                        a.click();
                        document.body.removeChild(a);

                        URL.revokeObjectURL(blobUrl);
                    } catch (error) {
                        console.error("Download failed:", error);
                    }
                };

                const deleteButton = document.createElement("button");
                deleteButton.innerHTML = `<b>Delete</b>`;
                deleteButton.classList.add("cardButton", "delete");

                deleteButton.onclick = async () => {
                    if (!confirm("Delete image?")) return;

                    const deleteApiUrl = `${currentEnv.apiBase}${currentEnv.getDeleteEndpoint(originalFilename)}`;
                        
                    try {
                        const response = await fetch(deleteApiUrl, {
                            method: "DELETE"
                        });

                        if(response.ok) {
                            card.remove();
                        } else {
                            console.error("Deletion failed, status:", response.status);
                        }
                    } catch(error) {
                        console.error("Deletion failed:", error);
                    }
                };

                card.appendChild(img);
                card.appendChild(info);
                card.appendChild(downloadButton);
                card.appendChild(deleteButton);
                images.appendChild(card);
            });
        } catch (error) {
            console.error("Loading images failed:", error);
        }
    }

    displayImages();
}
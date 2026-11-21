import "./styles.css";
import { mount } from "./ui/app.js";

const root = document.querySelector("#app");
if (root instanceof HTMLElement) mount(root);

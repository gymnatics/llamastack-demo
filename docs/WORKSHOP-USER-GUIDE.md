# 🎓 LlamaStack Workshop - User Guide

> **Welcome!** This guide will walk you through every step of the workshop. Don't worry if you're new to this - just follow along and copy-paste the commands exactly as shown.

---

## 📋 What You'll Learn Today

By the end of this workshop, you will:
- ✅ Deploy your own AI model on OpenShift (hands-on)
- ✅ Chat with your AI using a web interface (hands-on)
- ✅ See how MCP tools extend AI capabilities (demo)
- ✅ Understand how to add new tools via configuration (demo)

**Total time:** ~2 hours

### Workshop Structure

| Part | Type | Duration |
|------|------|----------|
| Part 1: Deploy Model | ✋ Hands-on | ~45 min |
| Part 2: Enable Playground & Test | ✋ Hands-on | ~20 min |
| Part 2.5+: MCP Tools & Notebook | 🎓 Admin Demo | ~30 min |
| Part 3: Add HR Tools | 🎓 Admin Demo | ~15 min |
| Part 4: Azure OpenAI | 🎓 Admin Demo | ~10 min |

---

## 🔢 Your User Number

Throughout this guide, you'll see `user-XX`. **Replace XX with your assigned number.**

For example, if you are **user 5**, then:
- `user-XX` becomes `user-05`
- `user-XX` becomes `user-05`

> ⚠️ **Important:** Always use two digits! User 5 = `user-05`, User 12 = `user-12`

**Write your user number here:** `user-____`

---

## 🖥️ Before We Start

### What You Need

1. **A web browser** (Chrome or Firefox recommended)
2. **Your login credentials** (username and password from your instructor)

### Your Login Credentials

Your instructor will give you:
- **Username:** `userXX` (e.g., `user01`, `user05`, `user12`)
- **Password:** (provided by instructor)

**Write your credentials here:**
- Username: `________`
- Password: `________`

---

# Part 1: Create Your Project & Deploy a Model (45 min)

## Step 1.1: Log into OpenShift

1. **Open** your web browser (Chrome or Firefox recommended)
2. **Go to** the URL your instructor provided
3. **Select** **"workshop-users"** as the login option
4. **Enter** your username and password
5. **Click** "Log in"

You should now see the **OpenShift Console**.

> ❓ **Can't log in?** Double-check your username and password. Ask your instructor if you're still stuck.

---

## Step 1.2: Navigate to OpenShift AI

Now let's go to the OpenShift AI Dashboard where we'll do most of our work.

1. **Look at** the top-right corner of the page
2. **Click** the **grid icon** (⊞) - it's a 3x3 grid of squares
3. **Click** **"OpenShift AI"** from the dropdown menu

You should now see the **OpenShift AI Dashboard** with a menu on the left side showing "Projects", "AI hub", "Gen AI studio", etc.

> 💡 **Tip:** You can always get back to OpenShift AI by clicking the grid icon and selecting "OpenShift AI".


---

## Step 1.3: Create Your Project

A "project" is your own workspace where you'll deploy your AI model.

1. **Click** on **"Projects"** in the left menu
2. **Click** the blue **"Create project"** button (top right)
3. **Fill in the form:**

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `user-XX` (use your number!) |
   | **Description** | `My workshop project` |

4. **Click** the **"Create"** button

✅ **Success!** You should now see your project `user-XX` in the list.

---

## Step 1.4: Understanding Hardware Profiles (Admin Demo)

> 🎓 **This is a demo by your instructor** - you don't need to do anything here, just watch and learn!

A "hardware profile" tells OpenShift what computer resources your AI model needs (like a GPU for fast processing). Your instructor will show you how hardware profiles work.

**What the instructor will show:**
- Where hardware profiles are configured (Settings → Hardware profiles)
- The `gpu-profile` that's already created for this workshop
- How it specifies CPU, Memory, and GPU resources
- Node selectors and tolerations (so pods run on GPU nodes)

> 📝 **Note:** Only administrators can create hardware profiles. As a user, you'll **select** the pre-created `gpu-profile` when deploying your model in the next step.

✅ **After the demo**, continue to the next step to deploy your model.


---

## Step 1.5: Add Model Details

A "model connection" tells OpenShift where to download the AI model from.

1. **Click** on **"Projects"** in the left menu
2. **Click** on your project name (`user-XX`)
3. **Click** on the **"Deployments"** tab
4. **Click** the **"Deploy Model"** button
5. **Select** **"URI"** as the connection type

6. **Fill in the form:**

   | Field | What to Enter |
   |-------|---------------|
   | **URI** | `oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct` |
   | **Name** | `llama-32-3b-instruct` |
   | **Model Type** | Generative AI Model |

   > 💡 **Tip:** Copy the URI exactly as shown above.

7. **Click** the **"Create"** button


✅ **Success!** You should see `llama-32-3b-instruct` in your connections list.


---

## Step 1.6: Add Model Deployment Details

Now let's deploy the actual AI model!

1. Make sure you're in your project (`user-XX`)
2. **Click** on the **"Models"** tab
3. **Click** the **"Deploy model"** button

4. **Fill in the deployment form:**

   | Field | What to Select/Enter |
   |-------|---------------------|
   | **Model deployment name** | `llama-32-3b-instruct` |
   | **Hardware profile** | Select `gpu-profile` (the one you created) |
   | **Serving runtime** | `vLLM NVIDIA GPU ServingRuntime for KServe` |


5. **Scroll down** to find **"Model server configuration"**
   - Set **Replicas** to `1`
   - ✅ Check the box **"Make deployed models available as AI assets"**



6. **Click** the **"Deploy"** button

---

## Step 1.7: Advanced Settings - Enable Tool Calling (Required for MCP!)

Now we need to enable **tool calling** so the model can use MCP servers. This is done in the "Advanced settings" step of the deployment wizard.

1. **Click** on **"3. Advanced settings"** in the left sidebar (or click Next)

2. **Under "Model playground availability":**
   - ✅ Check **"Add as AI asset endpoint"**

3. **Under "Model access":**
   - ✅ Check **"Make model deployment available through an external route"** (optional)
   - ✅ Check **"Require token authentication"** (optional, for security)

4. **Under "Configuration parameters":**
   - ✅ Check **"Add custom runtime arguments"**
   - **In the text box, enter these three lines** (copy and paste):

   ```
   --enable-auto-tool-choice
   --tool-call-parser=llama3_json
   --chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja
   ```

   > ⚠️ **Important:** Each argument must be on its own line!


5. **Click** the **"Deploy"** button

> 📝 **What do these arguments do?**
> - `--enable-auto-tool-choice` - Allows the model to decide when to use tools
> - `--tool-call-parser=llama3_json` - Tells vLLM how to parse tool calls for Llama models
> - `--chat-template` - Uses the correct chat format for tool calling

---

## Step 1.8: Wait for Your Model to Start

The model needs a few minutes to download and start up.

### Watch the Status in the Dashboard

1. **Stay on** the Deployments page, or go to **"Projects"** → your project (`user-XX`) → **"Deployments"** tab
2. **Watch** the status indicator next to `llama-32-3b-instruct`:
   - 🟡 **Pending** → Model is being prepared
   - 🔵 **Progressing** → Model is downloading/starting
   - 🟢 **Running** → Model is ready! ✅

> ⏱️ **This takes about 3-5 minutes.** Feel free to stretch or grab water!



✅ **Success!** Your AI model is now running with tool calling enabled!

---

# Part 2: Enable AI Playground & Test Your AI (30 min)

Now we'll enable the AI Playground and test your AI!

> 📝 **Note:** The MCP servers (Weather and HR) are already deployed and shared by your instructor. The instructor will demonstrate how to connect them to your AI later.

## Step 2.1: Open the Web Terminal

We need to run some commands. OpenShift has a built-in terminal in your browser!

1. **Look at** the top-right corner of the OpenShift Console
2. **Click** the **terminal icon** `>_` (it looks like this: `>_`)
3. **Wait** a few seconds for the terminal to start
4. You should see a terminal window appear at the bottom of your screen

> 💡 **Tip:** You can resize the terminal by dragging the top edge. You can also click the "expand" icon to make it full screen.

> ❓ **Don't see the terminal icon?** Ask your instructor for help.

## Step 2.2: Set Up Your Environment

**Step 1: Set your namespace variable** (replace XX with your number):

```bash
export NS=user-XX
```

For example, if you're user 5:
```bash
export NS=user-05
```

**Step 2: Clone the git repository in the web terminal:**

```bash
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo
git checkout workshop-branch
```

You should see:
```
Cloning into 'llamastack-demo'...
...
Switched to branch 'workshop-branch'
```

✅ **Success!** You now have all the workshop files.

---

## Step 2.3: Enable the AI Playground

The "Playground" is a chat interface where you can talk to your AI. When you enable it, a LlamaStack Distribution is created with your model.

1. **Go to** your project in the OpenShift AI Dashboard
2. **Click** on **"AI Asset Endpoints"** (in your project)
3. **Find** your model `llama-32-3b-instruct` in the list
4. **Click** the **"Add to Playground"** button next to it
5. **Wait** about 2 minutes for the Playground to be created

> 💡 You might see a loading indicator. Just wait for it to finish.

> ⚠️ **Important:** You may see MCP servers (Weather, HR) listed in the AI Asset Endpoints page. However, **they are NOT connected to your AI yet!** The Playground is created with a default configuration that has NO MCP tools. The instructor will show how to connect them later in the demo.

---

## Step 2.4: Test Your AI in the Playground!

Let's chat with your AI!

1. **Go to** the OpenShift AI Dashboard
2. **Click** on **"GenAI Studio"** in the left menu
3. **Click** on **"Playground"**
4. You should see a chat interface
5. **Select your model** from the dropdown (if not already selected)

### Try these prompts:

**Simple test:**
```
What is the capital of France?
```

Type it in the chat box and press Enter (or click Send).

**Try a few more:**
```
Explain machine learning in simple terms.
```

```
Write a haiku about coding.
```

```
What is 2 + 2?
```

🎉 **Your AI is working!** You can chat with it about anything.

> 📝 **Note:** Right now, your AI can only answer from its training data. In the next section, the instructor will show how to give it access to **live data** through MCP tools!

✅ **Success!** You've completed the hands-on portion of Part 2!

---

# 🎓 Part 2.5 onwards: Admin Demo

> **The following sections will be demonstrated by your instructor.** Sit back, watch, and learn how MCP tools work!

---

## What the Instructor Will Demonstrate

### 1. Connecting MCP Tools to LlamaStack

The instructor will show how to:
- Export the current LlamaStack configuration
- Add the Weather MCP server to the `tool_groups` section
- Apply the updated configuration
- Restart LlamaStack to pick up the changes

**Key concept:** MCP tools are connected by updating a ConfigMap - no code changes needed!

### 2. Testing MCP Tools in the Playground

After connecting the Weather MCP, the instructor will demonstrate:
- How to enable MCP tools in the Playground (click the lock icon)
- Asking weather-related questions:
  - "List all available weather stations"
  - "Get weather statistics"
  - "Get current weather for station VIDP"

**Key concept:** The AI can now access live weather data!

### 3. Direct Tool Invocation (Notebook Demo)

The instructor will show how to call MCP tools programmatically:
- List available models via the LlamaStack API
- List available tools (MCP servers)
- Call tools directly via `/v1/tool-runtime/invoke`
- Create an agent that automatically uses tools

**Key concept:** There are two ways to use MCP tools:
1. **Direct invocation** - Call specific tools when you know what you need
2. **Agent-based** - Let the AI decide which tools to use

### 4. Adding More Tools (HR MCP)

The instructor will demonstrate adding a second MCP server:
- Patch the ConfigMap to add HR MCP
- Restart LlamaStack
- Test HR tools: "List all employees", "Get vacation balance for EMP001"
- Use BOTH tools together: "List weather stations and list employees"

**Key concept:** Adding new capabilities is just a config change!

---

## 📝 What You're Learning

| Concept | What It Means |
|---------|---------------|
| **MCP Server** | A service that provides tools (like Weather or HR data) |
| **Tool Groups** | Collections of related tools from one MCP server |
| **ConfigMap** | Kubernetes configuration that tells LlamaStack which tools to use |
| **Direct Invocation** | Calling a specific tool by name |
| **Agent-Based** | Letting the AI decide which tools to use |

---

✅ **After the demo**, you'll understand how easy it is to extend AI capabilities with MCP tools!

---

# Part 3: Adding HR Tools (Admin Demo)

> 🎓 **This section is demonstrated by your instructor.**

The instructor will show how to add the HR MCP server, giving the AI access to employee data, vacation balances, and job openings.

## What You'll See

1. **Patching the ConfigMap** to add `mcp::hr-tools`
2. **Restarting LlamaStack** to pick up the new config
3. **Verifying** that HR tools are now available (~10 total tools)
4. **Testing in Playground:**
   - "List all employees"
   - "Get vacation balance for employee EMP001"
   - "List all job openings"
5. **Using BOTH tools together:**
   - "List weather stations and list all employees"

## Key Takeaway

| Before | After |
|--------|-------|
| 1 MCP server (Weather) | 2 MCP servers (Weather + HR) |
| ~5 tools | ~10 tools |
| Weather questions only | Weather + HR questions |

**Adding new AI capabilities = updating a config file. No coding required!**

---

# Part 4: Azure OpenAI Demo (Admin Demo)

> 🎓 **This section is demonstrated by your instructor.**

The instructor will show how LlamaStack can use multiple AI providers - both local (your GPU) and cloud (Azure OpenAI).

## What You'll See

1. **Adding Azure OpenAI** as a second inference provider
2. **Switching between providers** - same API, different backend
3. **Comparing responses** from local Llama vs Azure GPT-4

## Key Takeaway

- LlamaStack provides a **unified API** regardless of which AI provider you use
- You can mix local and cloud AI in the same application
- Switching providers is just a configuration change

> 📝 **Note:** Only the admin has the Azure API keys, so this is a demo only.


# 🎉 Congratulations!

You've completed the LlamaStack Workshop!

## What You Accomplished Today

### Hands-On (You Did It!)
✅ Created your own AI project on OpenShift  
✅ Deployed a real AI model (Llama 3.2-3B) with GPU acceleration  
✅ Enabled the AI Playground  
✅ Chatted with your AI using the web interface  

### Learned from Demo (Instructor Showed You)
✅ How to connect MCP tools (Weather, HR) to LlamaStack  
✅ How to call tools directly via the API  
✅ How to use agent-based tool calling  
✅ How to add multiple AI providers (local + Azure)  
✅ How easy it is to extend AI capabilities with configuration changes  

---

# 🧹 Cleanup (After the Workshop)

When you're done, you can delete your project to free up resources.

**In your terminal, run:**

```bash
oc delete project user-XX
```

(Replace `user-XX` with your actual user number)

Type `y` and press Enter if asked to confirm.

---

# 🆘 Troubleshooting

## "Command not found" error

Make sure you're logged into OpenShift:
```bash
oc whoami
```

If it says "error", you need to log in again (see "Logging into OpenShift" at the beginning).

## Model stuck on "Pending"

This usually means GPUs are busy. Wait a few minutes, or ask the instructor.

## Playground not loading

1. Make sure your model shows "Running" status
2. Try refreshing the browser page
3. Wait 2-3 minutes after enabling Playground

## "Permission denied" errors

Make sure you're working in YOUR project:
```bash
oc project user-XX
```

## Still stuck?

🙋 **Raise your hand!** The instructors are here to help.

---

# 📝 Quick Reference Card

## Your Info
- **Project name:** `user-____`
- **Namespace:** `user-____`

## Key Commands

```bash
# Set your namespace (do this first!)
export NS=user-XX

# Check your pods
oc get pods -n $NS

# Check available tools
oc exec deployment/lsd-genai-playground -n $NS -- curl -s http://localhost:8321/v1/tools

# Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n $NS

# View logs if something is wrong
oc logs deployment/lsd-genai-playground -n $NS --tail=50
```

## Shared MCP Server URLs

These MCP servers are shared and running in the `admin-workshop` namespace:

| Tool | URL |
|------|-----|
| Weather | `http://weather-mongodb-mcp.admin-workshop.svc.cluster.local:8000/mcp` |
| HR | `http://hr-mcp-server.admin-workshop.svc.cluster.local:8000/mcp` |

---

**Thank you for attending! 🙏**

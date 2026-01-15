# 🎓 LlamaStack Workshop - User Guide

> **Welcome!** This guide will walk you through every step of the workshop. Don't worry if you're new to this - just follow along and copy-paste the commands exactly as shown.

---

## 📋 What You'll Learn Today

By the end of this workshop, you will:
- ✅ Deploy your own AI model on OpenShift
- ✅ Connect AI tools (MCP servers) to your model
- ✅ Chat with your AI using a web interface
- ✅ See how easy it is to add new capabilities to AI

**Total time:** ~2.5 hours

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
2. **Access to OpenShift AI Dashboard** (your instructor will provide the URL)
3. **A terminal** (for running commands)

### Opening Your Terminal

**On Mac:**
1. Press `Cmd + Space` to open Spotlight
2. Type `Terminal`
3. Press `Enter`

**On Windows:**
1. Press `Windows key`
2. Type `cmd` or `PowerShell`
3. Press `Enter`

**On Linux:**
1. Press `Ctrl + Alt + T`

### Logging into OpenShift

Your instructor will give you a login command. It looks like this:

```bash
oc login --token=sha256~xxxxx --server=https://api.cluster.example.com:6443
```

1. Copy the command your instructor provides
2. Paste it into your terminal
3. Press `Enter`

You should see:
```
Logged into "https://api.cluster.example.com:6443" as "your-username"
```

> ❓ **Stuck?** Raise your hand and ask for help!

---

# Part 1: Create Your Project & Deploy a Model (45 min)

## Step 1.1: Open the OpenShift AI Dashboard

1. Open your web browser
2. Go to the URL your instructor provided
3. Log in with your credentials

You should see the **OpenShift AI Dashboard** with a menu on the left side.

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.1-dashboard-home.png`
> - Show: OpenShift AI Dashboard home page after login
> - Highlight: Left menu showing "Data Science Projects", "Settings", etc.
> - Size: Full browser window

---

## Step 1.2: Create Your Project

A "project" is your own workspace where you'll deploy your AI model.

1. **Click** on **"Data Science Projects"** in the left menu
2. **Click** the blue **"Create data science project"** button (top right)
3. **Fill in the form:**

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `user-XX` (use your number!) |
   | **Description** | `My workshop project` |

4. **Click** the **"Create"** button

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.2a-create-project-form.png`
> - Show: "Create data science project" dialog/form
> - Highlight: Name field filled with "user-01" as example
> - Size: Dialog only (cropped)

✅ **Success!** You should now see your project `user-XX` in the list.

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.2b-project-created.png`
> - Show: Data Science Projects list with newly created project
> - Highlight: The new project in the list
> - Size: Main content area

---

## Step 1.3: Create a Hardware Profile

A "hardware profile" tells OpenShift what computer resources your AI model needs (like a GPU for fast processing).

1. **Click** on **"Settings"** in the left menu
2. **Click** on **"Hardware profiles"**
3. **Click** the **"Create hardware profile"** button

4. **Fill in the basic info:**

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `gpu-profile` |
   | **Display name** | `GPU Profile` |
   | **Description** | `Profile with GPU for AI models` |

5. **Add the resources** (click "Add identifier" for each):

   **First resource (CPU):**
   | Field | Value |
   |-------|-------|
   | Display name | `CPU` |
   | Identifier | `cpu` |
   | Resource type | `CPU` |
   | Default | `4` |
   | Minimum | `1` |
   | Maximum | `8` |

   **Second resource (Memory):**
   | Field | Value |
   |-------|-------|
   | Display name | `Memory` |
   | Identifier | `memory` |
   | Resource type | `Memory` |
   | Default | `16Gi` |
   | Minimum | `8Gi` |
   | Maximum | `32Gi` |

   **Third resource (GPU):**
   | Field | Value |
   |-------|-------|
   | Display name | `GPU` |
   | Identifier | `nvidia.com/gpu` |
   | Resource type | `Accelerator` |
   | Default | `1` |
   | Minimum | `1` |
   | Maximum | `1` |

6. **Click** the **"Create"** button

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.3a-hardware-profile-form.png`
> - Show: Hardware profile creation form
> - Highlight: Name field, and the three resource identifiers (CPU, Memory, GPU)
> - Size: Full form view

✅ **Success!** You should see `gpu-profile` in the hardware profiles list.

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.3b-hardware-profile-created.png`
> - Show: Hardware profiles list with "gpu-profile" visible
> - Highlight: The new gpu-profile entry
> - Size: Main content area

---

## Step 1.4: Create a Model Connection

A "model connection" tells OpenShift where to download the AI model from.

1. **Click** on **"Data Science Projects"** in the left menu
2. **Click** on your project name (`user-XX`)
3. **Click** on the **"Connections"** tab
4. **Click** the **"Add connection"** button
5. **Select** **"URI"** as the connection type

6. **Fill in the form:**

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `llama-32-3b-instruct` |
   | **URI** | (copy the text below exactly) |

   ```
   oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct
   ```

   > 💡 **Tip:** Triple-click the URI above to select it all, then copy and paste.

7. **Click** the **"Create"** button

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.4a-connection-form.png`
> - Show: Add connection form with URI type selected
> - Highlight: Name field and URI field filled in
> - Size: Dialog/form only

✅ **Success!** You should see `llama-32-3b-instruct` in your connections list.

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.4b-connection-created.png`
> - Show: Connections tab with the new connection listed
> - Highlight: The llama-32-3b-instruct connection
> - Size: Main content area

---

## Step 1.5: Deploy Your AI Model

Now let's deploy the actual AI model!

1. Make sure you're in your project (`user-XX`)
2. **Click** on the **"Models"** tab
3. **Click** the **"Deploy model"** button

4. **Fill in the deployment form:**

   | Field | What to Select/Enter |
   |-------|---------------------|
   | **Model name** | `llama-32-3b-instruct` |
   | **Serving runtime** | `vLLM NVIDIA GPU ServingRuntime for KServe` |
   | **Model framework** | `vLLM` |
   | **Hardware profile** | Select `gpu-profile` (the one you created) |
   | **Model connection** | Select `llama-32-3b-instruct` |

5. **Scroll down** to find **"Model server configuration"**
   - Set **Replicas** to `1`
   - ✅ Check the box **"Make deployed models available as AI assets"**

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.5a-deploy-model-form-top.png`
> - Show: Top part of Deploy model form
> - Highlight: Model name, Serving runtime dropdown, Hardware profile dropdown
> - Size: Upper half of form

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.5b-deploy-model-form-bottom.png`
> - Show: Bottom part of Deploy model form
> - Highlight: "Make deployed models available as AI assets" checkbox (checked)
> - Size: Lower half of form

6. **Click** the **"Deploy"** button

---

## Step 1.6: Enable Tool Calling (Required for MCP!)

The model is deployed, but we need to enable **tool calling** so it can use MCP servers. This requires a quick terminal command.

### Open Your Terminal

**On Mac:** Press `Cmd + Space`, type `Terminal`, press `Enter`
**On Windows:** Press `Windows key`, type `cmd` or `PowerShell`, press `Enter`
**On Linux:** Press `Ctrl + Alt + T`

### Run the Patch Command

**Step 1: Set your namespace variable** (replace XX with your number):

```bash
export NS=user-XX
```

For example, if you're user 5:
```bash
export NS=user-05
```

**Step 2: Enable tool calling on your model:**

```bash
oc patch servingruntime llama-32-3b-instruct -n $NS --type='json' -p='[
  {"op": "add", "path": "/spec/containers/0/args/-", "value": "--enable-auto-tool-choice"},
  {"op": "add", "path": "/spec/containers/0/args/-", "value": "--tool-call-parser=llama3_json"},
  {"op": "add", "path": "/spec/containers/0/args/-", "value": "--chat-template=/opt/app-root/template/tool_chat_template_llama3.2_json.jinja"}
]'
```

You should see:
```
servingruntime.serving.kserve.io/llama-32-3b-instruct patched
```

**Step 3: Restart the model to apply changes:**

```bash
oc delete pod -l serving.kserve.io/inferenceservice=llama-32-3b-instruct -n $NS
```

> 📝 **What did we just do?**
> - Added `--enable-auto-tool-choice` - Allows the model to decide when to use tools
> - Added `--tool-call-parser=llama3_json` - Tells vLLM how to parse tool calls for Llama models
> - Added `--chat-template` - Uses the correct chat format for tool calling

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.6-terminal-patch.png`
> - Show: Terminal with the patch command and success output
> - Highlight: "patched" message
> - Size: Terminal window

---

## Step 1.7: Wait for Your Model to Restart

After the patch, the model needs to restart. This takes a few minutes.

### Watch the Status in the Dashboard

1. **Go back to** the OpenShift AI Dashboard
2. **Click** on **"Data Science Projects"** → your project (`user-XX`) → **"Models"** tab
3. **Watch** the status indicator next to `llama-32-3b-instruct`:
   - 🟡 **Pending** → Model is restarting
   - 🔵 **Progressing** → Model is starting up
   - 🟢 **Running** → Model is ready! ✅

> ⏱️ **This takes about 3-5 minutes.** Feel free to stretch or grab water!

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.7a-model-pending.png`
> - Show: Models list with model in "Pending" or "Progressing" status
> - Highlight: Status indicator (yellow/blue)
> - Size: Main content area

### Or Check in Your Terminal

You can also wait using the terminal:

```bash
echo "⏳ Waiting for model to restart (this takes 3-5 minutes)..."
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=llama-32-3b-instruct -n $NS --timeout=300s
echo "✅ Model is ready with tool calling enabled!"
```

**Or check manually:**

```bash
oc get pods -n $NS | grep llama
```

When it's ready, you'll see:
```
llama-32-3b-instruct-predictor-xxxxx   3/3   Running   0   2m
```

The `3/3` and `Running` mean it's working!

> 📸 **SCREENSHOT NEEDED:** `screenshot-1.7b-model-running.png`
> - Show: Models list with model in "Running" status (green)
> - Highlight: Green status indicator
> - Size: Main content area

✅ **Success!** Your AI model is now running with tool calling enabled!

---

# Part 2: Add AI Tools & Test the Playground (30 min)

Now we'll add "tools" that give your AI special abilities, like checking the weather!

## Step 2.1: Download the Workshop Files

First, let's download the files we need for deploying the MCP tools.

**Make sure your terminal is open and your namespace is set:**

```bash
# Check if NS is set
echo $NS
```

If it shows nothing, set it again (replace XX with your number):
```bash
export NS=user-XX
```

**Now download the workshop files:**

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

## Step 2.2: Deploy the Weather Tool

Let's give your AI the ability to check the weather!

**Copy and paste this command:**

```bash
oc apply -f manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml -n $NS
```

Press `Enter`. You'll see several lines saying things were "created".

---

## Step 2.3: Deploy the HR Tool

Let's also deploy an HR (Human Resources) tool. We'll use it later!

**Copy and paste this command:**

```bash
oc apply -f manifests/workshop/deploy-hr-mcp-simple.yaml -n $NS
```

Press `Enter`.

---

## Step 2.5: Wait for the Tools to Start

The tools need a minute to start up. Let's wait for them.

**Copy and paste these commands one at a time:**

```bash
echo "⏳ Waiting for Weather tool..."
oc wait --for=condition=available deployment/mongodb -n $NS --timeout=120s
oc wait --for=condition=complete job/init-weather-data -n $NS --timeout=120s
oc wait --for=condition=available deployment/weather-mongodb-mcp -n $NS --timeout=180s
echo "✅ Weather tool ready!"
```

```bash
echo "⏳ Waiting for HR tool..."
oc wait --for=condition=available deployment/hr-mcp-server -n $NS --timeout=180s
echo "✅ HR tool ready!"
```

When you see `✅ Weather tool ready!` and `✅ HR tool ready!`, you're good to go!

---

## Step 2.6: See Your Tools in the Dashboard

Let's see what we just deployed in the OpenShift AI Dashboard!

1. **Go to** your project in the OpenShift AI Dashboard
2. **Click** on **"Workloads"** → **"Pods"** in the OpenShift Console (not the AI Dashboard)
   - Or run `oc get pods -n $NS` in your terminal

You should see several pods running:
- `mongodb-xxxxx` - Database for weather data
- `weather-mongodb-mcp-xxxxx` - Weather MCP server
- `hr-mcp-server-xxxxx` - HR MCP server
- `llama-32-3b-instruct-predictor-xxxxx` - Your AI model

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.6-pods-running.png`
> - Show: Pod list showing all running pods (model + MCP servers)
> - Highlight: The MCP server pods
> - Size: Main content area

---

## Step 2.7: Register MCP Servers (Admin Step)

Before we can use MCP servers, they need to be registered in OpenShift AI. This is done by applying a ConfigMap to the `redhat-ods-applications` namespace.

> 📝 **Note:** Your instructor may have already done this step for the whole cluster. Check with them first!

**If MCP servers are NOT already registered, run this command:**

```bash
# Register MCP servers in AI Asset Endpoints (cluster-wide)
oc apply -f manifests/workshop/gen-ai-aa-mcp-servers-workshop.yaml
```

**To verify MCP servers are registered:**

1. **Go to** the OpenShift AI Dashboard
2. **Click** on **"Settings"** in the left menu
3. **Click** on **"AI asset endpoints"**
4. You should see **Weather-MCP-Server** and **HR-MCP-Server** in the list

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.7-ai-asset-endpoints.png`
> - Show: Settings → AI asset endpoints page
> - Highlight: Weather-MCP-Server and HR-MCP-Server entries
> - Size: Main content area

---

## Step 2.8: Enable the AI Playground

The "Playground" is a chat interface where you can talk to your AI. When you enable it, a LlamaStack Distribution is created with your model.

1. **Go to** your project in the OpenShift AI Dashboard
2. **Click** on **"AI Asset Endpoints"** (in your project, not Settings)
3. **Find** your model `llama-32-3b-instruct` in the list
4. **Click** the **"Add to Playground"** button next to it
5. **Wait** about 2 minutes for the Playground to be created

> 💡 You might see a loading indicator. Just wait for it to finish.

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.8a-add-to-playground-button.png`
> - Show: AI Asset Endpoints page with model listed
> - Highlight: "Add to Playground" button next to the model
> - Size: Row containing the model

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.8b-playground-creating.png`
> - Show: Loading/creating indicator for Playground
> - Highlight: Progress indicator
> - Size: Relevant portion of screen

---

## Step 2.8.5: Add Weather MCP to LlamaStack Config

Now we need to add the Weather MCP server to the LlamaStack configuration. The Playground created a ConfigMap called `llama-stack-config` - we'll patch it to add the MCP.

**Go back to your terminal and run these commands:**

```bash
# Step 1: Get the current config
oc get configmap llama-stack-config -n $NS -o jsonpath='{.data.run\.yaml}' > /tmp/current-config.yaml

# Step 2: Check current tool_groups (should only have builtin::rag)
echo "Current tool_groups:"
grep -A5 "tool_groups:" /tmp/current-config.yaml
```

You should see only `builtin::rag`. Now let's add the Weather MCP:

```bash
# Step 3: Add Weather MCP to the config
cat /tmp/current-config.yaml | sed 's/tool_groups:/tool_groups:\
- toolgroup_id: mcp::weather-data\
  provider_id: model-context-protocol\
  mcp_endpoint:\
    uri: http:\/\/weather-mongodb-mcp:8000\/mcp/' > /tmp/patched-config.yaml

# Step 4: Verify the patch looks correct
echo "Patched tool_groups:"
grep -A10 "tool_groups:" /tmp/patched-config.yaml
```

You should now see both `mcp::weather-data` and `builtin::rag`.

```bash
# Step 5: Apply the patched config
oc create configmap llama-stack-config \
  --from-file=run.yaml=/tmp/patched-config.yaml \
  -n $NS \
  --dry-run=client -o yaml | oc replace -f -

# Step 6: Restart LlamaStack to pick up the new config
oc delete pod -l app=lsd-genai-playground -n $NS

# Step 7: Wait for restart
echo "⏳ Waiting for LlamaStack to restart..."
sleep 20
oc wait --for=condition=ready pod -l app=lsd-genai-playground -n $NS --timeout=120s
echo "✅ LlamaStack restarted!"
```

> 📝 **What just happened?** 
> - We exported the current config created by the operator
> - Added the Weather MCP to the `tool_groups` section
> - Replaced the ConfigMap with the patched version
> - Restarted the pod to load the new config

---

## Step 2.9: Test Your AI in the Playground!

The "Playground" is a chat interface where you can talk to your AI.

1. Stay on the **"AI Asset Endpoints"** page
2. **Find** your model `llama-32-3b-instruct` in the list
3. **Click** the **"Add to Playground"** button next to it
4. **Wait** about 2 minutes for the Playground to be created

> 💡 You might see a loading indicator. Just wait for it to finish.

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.8a-add-to-playground-button.png`
> - Show: AI Asset Endpoints page with model listed
> - Highlight: "Add to Playground" button next to the model
> - Size: Row containing the model

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.8b-playground-creating.png`
> - Show: Loading/creating indicator for Playground
> - Highlight: Progress indicator
> - Size: Relevant portion of screen

---

## Step 2.9: Test Your AI in the Playground!

Let's chat with your AI!

1. **Go to** the OpenShift AI Dashboard
2. **Click** on **"GenAI Studio"** in the left menu
3. **Click** on **"Playground"**
4. You should see a chat interface
5. **Select your model** from the dropdown (if not already selected)

### Try these prompts:

**First, a simple test:**
```
What is the capital of France?
```

Type it in the chat box and press Enter (or click Send).

**Now, test the weather tool:**
```
What is the weather in New York City?
```

🎉 **Amazing!** Your AI is using the weather tool to get real data!

**Try more weather questions:**
```
List all available weather stations
```

```
What's the weather in Tokyo?
```

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.9a-playground-interface.png`
> - Show: GenAI Studio Playground chat interface
> - Highlight: Model selector dropdown, chat input box
> - Size: Full Playground view

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.9b-playground-simple-response.png`
> - Show: Playground with "What is the capital of France?" and response
> - Highlight: The AI's response
> - Size: Chat area

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.9c-playground-weather-tool.png`
> - Show: Playground with weather query and response showing tool usage
> - Highlight: Tool call indicator (if visible) and weather data in response
> - Size: Chat area

---

## Step 2.10: Check What Tools Are Available

Let's verify what tools your AI can use right now.

**Go to your terminal and copy-paste this command:**

```bash
oc exec deployment/lsd-genai-playground -n $NS -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
mcps=[t for t in tools if t.get('toolgroup_id','').startswith('mcp::')]
print('='*50)
print(f'🛠️  Available Tools: {len(mcps)}')
print('='*50)
for t in mcps:
    print(f\"  • {t.get('name')}\")"
```

You should see about **3 tools** (all weather-related).

> 📝 **Note:** The HR tool is deployed but not connected to your AI yet. We'll do that in Part 3!

---

## Step 2.11: Run the Notebook (First Time)

A "notebook" is an interactive document where you can run code. Let's try it!

### Create a Workbench:

1. **Go to** your project in OpenShift AI Dashboard
2. **Click** on **"Workbenches"** tab
3. **Click** **"Create workbench"**
4. **Fill in:**

   | Field | What to Select/Enter |
   |-------|---------------------|
   | **Name** | `workshop-notebook` |
   | **Image** | Select one that says `Jupyter` and `Python 3.11` or `3.12` |
   | **Container size** | `Small` is fine |

5. **Click** **"Create"**
6. **Wait** for the status to show **"Running"** (1-2 minutes)
7. **Click** the **"Open"** link to launch JupyterLab

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11a-create-workbench.png`
> - Show: Create workbench form
> - Highlight: Name field, Image selector, Container size
> - Size: Form view

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11b-workbench-running.png`
> - Show: Workbenches list with workbench in "Running" status
> - Highlight: "Open" link
> - Size: Main content area

### Get the Workshop Notebook:

8. In JupyterLab, look at the top menu
9. **Click** **"Git"** → **"Clone a Repository"**
10. **Paste** this URL:
    ```
    https://github.com/<org>/llamastack-demo.git
    ```
11. **Click** **"Clone"**
12. In the file browser on the left, **navigate to:**
    `llamastack-demo` → `notebooks` → `workshop_client_demo.ipynb`
13. **Double-click** to open it

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11c-jupyterlab-git-clone.png`
> - Show: JupyterLab with Git > Clone a Repository dialog
> - Highlight: URL input field
> - Size: Dialog and part of JupyterLab

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11d-jupyterlab-file-browser.png`
> - Show: JupyterLab file browser showing llamastack-demo/notebooks folder
> - Highlight: workshop_client_demo.ipynb file
> - Size: Left sidebar file browser

### Run the Notebook:

14. **Find the cell** that says `PROJECT_NAME = "user-XX"`
15. **Change** `user-XX` to your actual user number (e.g., `user-05`)
16. **Click** the **"Run All"** button (▶▶) at the top, or go to **Run** → **Run All Cells**

**Look at the output!** You should see:
- 1 LLM model available
- About 3 MCP tools (Weather only)

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11e-notebook-project-name.png`
> - Show: Notebook cell with PROJECT_NAME variable
> - Highlight: The cell where user changes "user-XX" to their number
> - Size: Single cell

> 📸 **SCREENSHOT NEEDED:** `screenshot-2.11f-notebook-output-phase1.png`
> - Show: Notebook output showing models and tools (Phase 1)
> - Highlight: "LLM Models: 1" and "MCP Tools: 3" (or similar)
> - Size: Output cells showing results

✅ **Success!** You've completed Part 2!

---

# Part 3: Add More Tools to Your AI (30 min)

Now let's add the HR tool to your AI. This shows how easy it is to expand your AI's capabilities!

## Step 3.1: See the Current Configuration

Let's look at what tools your AI is currently configured to use.

**In your terminal, run:**

```bash
oc get configmap llama-stack-config -n $NS -o jsonpath='{.data.run\.yaml}' | grep -A10 "tool_groups:"
```

You'll see something like:
```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mongodb-mcp:8000/mcp
- toolgroup_id: builtin::rag
  provider_id: rag-runtime
```

Notice: Only Weather MCP and builtin RAG are listed - no HR MCP yet!

---

## Step 3.2: Add HR MCP to the Configuration

Now let's add the HR MCP tool to the configuration using the same patching approach.

**Copy and paste these commands:**

```bash
# Step 1: Get the current config
oc get configmap llama-stack-config -n $NS -o jsonpath='{.data.run\.yaml}' > /tmp/current-config.yaml

# Step 2: Add HR MCP to the config (after Weather MCP)
cat /tmp/current-config.yaml | sed 's/- toolgroup_id: builtin::rag/- toolgroup_id: mcp::hr-tools\
  provider_id: model-context-protocol\
  mcp_endpoint:\
    uri: http:\/\/hr-mcp-server:8000\/mcp\
- toolgroup_id: builtin::rag/' > /tmp/patched-config.yaml

# Step 3: Verify the patch
echo "New tool_groups:"
grep -A15 "tool_groups:" /tmp/patched-config.yaml
```

You should now see **three** entries: `mcp::weather-data`, `mcp::hr-tools`, and `builtin::rag`.

```bash
# Step 4: Apply the patched config
oc create configmap llama-stack-config \
  --from-file=run.yaml=/tmp/patched-config.yaml \
  -n $NS \
  --dry-run=client -o yaml | oc replace -f -

echo "✅ Config updated!"
```

---

## Step 3.3: Restart the AI to Apply Changes

The AI needs to restart to pick up the new configuration.

**Copy and paste these commands:**

```bash
echo "🔄 Restarting your AI..."
oc delete pod -l app=lsd-genai-playground -n $NS
```

```bash
echo "⏳ Waiting for AI to restart (about 30 seconds)..."
sleep 30
oc wait --for=condition=ready pod -l app=lsd-genai-playground -n $NS --timeout=120s
echo "✅ AI is ready with new tools!"
```

---

## Step 3.4: Verify the New Tools

Let's check that the HR tool is now available.

**Copy and paste this command:**

```bash
oc exec deployment/lsd-genai-playground -n $NS -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
groups={}
for t in tools:
    tg=t.get('toolgroup_id','')
    if tg not in groups: groups[tg]=[]
    groups[tg].append(t.get('name'))
print('='*50)
print(f'🛠️  Total Tools: {len(tools)}')
print('='*50)
for tg,names in sorted(groups.items()):
    print(f'\n📦 {tg}:')
    for n in names:
        print(f'   • {n}')"
```

You should now see **about 8 tools**, including:
- Weather tools (from before)
- HR tools (NEW!) like `list_employees`, `get_vacation_balance`, etc.

---

## Step 3.5: Test the HR Tool in the Playground

Go back to the **Playground** in your browser and try these prompts:

**List employees:**
```
List all employees in the company
```

**Check vacation balance:**
```
What is the vacation balance for employee EMP001?
```

**Find job openings:**
```
What job openings are available?
```

**Create a vacation request:**
```
Create a vacation request for EMP002 from 2026-02-10 to 2026-02-14
```

**Use BOTH tools in one question:**
```
What's the weather in Tokyo, and how many vacation days does Alice Johnson have?
```

🎉 **Your AI is now using BOTH the weather AND HR tools!**

> 📸 **SCREENSHOT NEEDED:** `screenshot-3.5a-playground-hr-employees.png`
> - Show: Playground with "List all employees" query and response
> - Highlight: Employee list in the response
> - Size: Chat area

> 📸 **SCREENSHOT NEEDED:** `screenshot-3.5b-playground-hr-vacation.png`
> - Show: Playground with vacation balance query and response
> - Highlight: Vacation balance information
> - Size: Chat area

> 📸 **SCREENSHOT NEEDED:** `screenshot-3.5c-playground-combined-query.png`
> - Show: Playground with combined weather+HR query
> - Highlight: Response showing both weather AND HR data
> - Size: Chat area (this is a key screenshot!)

---

## Step 3.6: What You Just Learned

| Before (Part 2) | After (Part 3) |
|-----------------|----------------|
| 1 tool group (Weather) | 2 tool groups (Weather + HR) |
| ~3 tools | ~8 tools |
| Weather questions only | Weather + HR questions |

**Key takeaway:** You added new capabilities to your AI by just updating a configuration file - no coding required!

---

# Part 4: Watch the Admin Demo (30 min)

Now the instructor will show you something cool: adding a cloud AI (Azure OpenAI) alongside your local AI.

**What you'll see:**
- The same LlamaStack can use multiple AI providers
- Switch between local (your GPU) and cloud (Azure) with one setting
- The API stays the same - your code doesn't need to change!

> 📝 **Note:** Only the admin has the Azure API keys, so this is a demo only.

---

# Part 5: Re-run the Notebook (30 min)

Remember the notebook you ran in Part 2? Let's run it again and see the difference!

## Step 5.1: Open Your Notebook

1. Go back to your **Workbench** (JupyterLab)
2. Open `workshop_client_demo.ipynb` if it's not already open

## Step 5.2: Restart and Re-run

1. **Click** on **"Kernel"** in the top menu
2. **Click** **"Restart Kernel and Run All Cells"**
3. **Click** **"Restart"** to confirm

## Step 5.3: Compare the Results!

**Part 2 (first run):**
- MCP Tools: ~3 (Weather only)

**Part 5 (second run):**
- MCP Tools: ~8 (Weather + HR)

🎯 **The notebook code didn't change at all!** The same code automatically discovered the new HR tools because you updated the LlamaStack configuration.

> 📸 **SCREENSHOT NEEDED:** `screenshot-5.3-notebook-output-phase2.png`
> - Show: Notebook output showing models and tools (Phase 2)
> - Highlight: "MCP Tools: 8" (or similar) - MORE than Phase 1!
> - Size: Output cells showing results
> - Note: This should be visually comparable to screenshot-2.11f to show the difference

## Step 5.4: Try Some Queries in the Notebook

Find the cell where you can enter your own question and try:

```python
my_question = "What's the weather in London and who are the employees in Engineering?"
```

Run that cell to see your AI use both tools!

---

# 🎉 Congratulations!

You've completed the LlamaStack Workshop!

## What You Accomplished Today

✅ Created your own AI project on OpenShift  
✅ Deployed a real AI model (Llama 3.2)  
✅ Added tools (MCP servers) to give your AI special abilities  
✅ Used the Playground to chat with your AI  
✅ Updated your AI's configuration to add new tools  
✅ Ran notebooks to interact with your AI programmatically  
✅ Learned how LlamaStack makes it easy to extend AI capabilities  

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

## Notebook connection error

Make sure you updated `PROJECT_NAME` to match your actual project:
```python
PROJECT_NAME = "user-05"  # Use YOUR number!
```

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

## Important URLs (for MCP registration)

| Tool | URL |
|------|-----|
| Weather | `http://weather-mongodb-mcp:8000/mcp` |
| HR | `http://hr-mcp-server:8000/mcp` |

---

**Thank you for attending! 🙏**

---

# 📸 Screenshot Checklist for Instructors

Use this checklist to capture all required screenshots before the workshop.

## Part 1: Create Project & Deploy Model

| # | Filename | What to Capture |
|---|----------|-----------------|
| 1 | `screenshot-1.1-dashboard-home.png` | OpenShift AI Dashboard home page after login |
| 2 | `screenshot-1.2a-create-project-form.png` | "Create data science project" dialog with name filled |
| 3 | `screenshot-1.2b-project-created.png` | Data Science Projects list showing new project |
| 4 | `screenshot-1.3a-hardware-profile-form.png` | Hardware profile form with CPU/Memory/GPU identifiers |
| 5 | `screenshot-1.3b-hardware-profile-created.png` | Hardware profiles list showing gpu-profile |
| 6 | `screenshot-1.4a-connection-form.png` | Add connection form (URI type) with fields filled |
| 7 | `screenshot-1.4b-connection-created.png` | Connections tab showing the model connection |
| 8 | `screenshot-1.5a-deploy-model-form-top.png` | Deploy model form - top (name, runtime, hardware) |
| 9 | `screenshot-1.5b-deploy-model-form-bottom.png` | Deploy model form - bottom (AI assets checkbox) |
| 10 | `screenshot-1.6a-model-pending.png` | Models list with Pending/Progressing status |
| 11 | `screenshot-1.6b-model-running.png` | Models list with Running status (green) |

## Part 2: Deploy MCPs & Enable Playground

| # | Filename | What to Capture |
|---|----------|-----------------|
| 12 | `screenshot-2.7a-add-to-playground-button.png` | Model row with "Add to Playground" button |
| 13 | `screenshot-2.7b-playground-creating.png` | Playground creation progress indicator |
| 14 | `screenshot-2.9a-playground-interface.png` | GenAI Studio Playground - full interface |
| 15 | `screenshot-2.9b-playground-simple-response.png` | Playground with simple Q&A (capital of France) |
| 16 | `screenshot-2.9c-playground-weather-tool.png` | Playground showing weather tool in action |
| 17 | `screenshot-2.11a-create-workbench.png` | Create workbench form |
| 18 | `screenshot-2.11b-workbench-running.png` | Workbenches list with "Open" link |
| 19 | `screenshot-2.11c-jupyterlab-git-clone.png` | JupyterLab Git clone dialog |
| 20 | `screenshot-2.11d-jupyterlab-file-browser.png` | JupyterLab file browser showing notebook |
| 21 | `screenshot-2.11e-notebook-project-name.png` | Notebook cell with PROJECT_NAME variable |
| 22 | `screenshot-2.11f-notebook-output-phase1.png` | Notebook output - Phase 1 (~3 tools) |

## Part 3: Add HR MCP to LlamaStack

| # | Filename | What to Capture |
|---|----------|-----------------|
| 23 | `screenshot-3.5a-playground-hr-employees.png` | Playground with employee list response |
| 24 | `screenshot-3.5b-playground-hr-vacation.png` | Playground with vacation balance response |
| 25 | `screenshot-3.5c-playground-combined-query.png` | Playground with combined weather+HR query ⭐ |

## Part 5: Re-run Notebook

| # | Filename | What to Capture |
|---|----------|-----------------|
| 26 | `screenshot-5.3-notebook-output-phase2.png` | Notebook output - Phase 2 (~8 tools) |

---

## Screenshot Tips

1. **Use a clean browser** - No bookmarks bar, minimal extensions visible
2. **Consistent window size** - Use same browser window size for all screenshots
3. **Highlight important areas** - Use red boxes/arrows to draw attention
4. **Crop appropriately** - Remove unnecessary whitespace but keep context
5. **Use example data** - Use `user-01` as the example user in screenshots
6. **High resolution** - Capture at 2x resolution if possible for clarity

## Recommended Tools

- **Mac:** Built-in Screenshot (Cmd+Shift+4) or CleanShot X
- **Windows:** Snipping Tool or ShareX
- **Annotation:** Skitch, Markup Hero, or built-in Preview (Mac)

---

## Folder Structure for Screenshots

```
docs/
├── WORKSHOP-USER-GUIDE.md
└── images/
    ├── screenshot-1.1-dashboard-home.png
    ├── screenshot-1.2a-create-project-form.png
    ├── screenshot-1.2b-project-created.png
    └── ... (all other screenshots)
```

After capturing screenshots, update this guide to reference them:
```markdown
![Dashboard Home](images/screenshot-1.1-dashboard-home.png)
```

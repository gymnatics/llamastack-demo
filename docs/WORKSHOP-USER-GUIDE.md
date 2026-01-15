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
   | **URI** | (copy the text below exactly) |

   ```
   oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct
   ```   
   | **Name** | `llama-32-3b-instruct` |
   | **Model Type** | Generative AI Model |

   > 💡 **Tip:** Triple-click the URI above to select it all, then copy and paste.

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

# Part 2: Enable AI Playground & Add Weather Tool (30 min)

Now we'll enable the AI Playground and connect a weather tool to give your AI special abilities!

> 📝 **Note:** The MCP servers (Weather and HR) are already deployed and shared by your instructor. You just need to connect them to your AI!

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

**Step 2: Download the workshop files (for notebooks later):**

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

> ⚠️ **Important:** You may see MCP servers (Weather, HR) listed in the AI Asset Endpoints page. However, **they are NOT connected to your AI yet!** The Playground is created with a default configuration that has NO MCP tools. We'll add them in the next step.

---

## Step 2.4: Test Your AI in the Playground!

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

**Now, test the weather tools:**

> 💡 **Tip:** The weather tools work best with specific requests. Here are some recommended prompts:

**List available stations (simple, always works):**
```
List all available weather stations
```

**Get weather statistics:**
```
Get weather statistics
```

**Search for weather by location:**
```
Search for weather observations in New Delhi
```

```
Search for weather in Tokyo with limit 3
```

**Get current weather for a specific station:**
```
Get current weather for station VIDP
```

> 📝 **Station codes:** VIDP = New Delhi, RJTT = Tokyo, KJFK = New York, EGLL = London, YSSY = Sydney

🎉 **Amazing!** Your AI is using the weather tool to get real data!

> ⚠️ **Troubleshooting:** If you get an error about "parameters could not be parsed", try using simpler prompts like "List all weather stations" or "Get weather statistics". The model sometimes has trouble with complex queries.

---

## Step 2.5: Add Weather MCP to LlamaStack Config

Now we need to connect the Weather MCP server to your AI. The Playground created a ConfigMap called `llama-stack-config` - we'll patch it to add the MCP.

> 📝 **Note:** The Weather MCP server is shared and running in the `admin-workshop` namespace. We just need to tell your AI where to find it!

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
# Step 3: Add Weather MCP to the config (using shared server in admin-workshop)
cat /tmp/current-config.yaml | sed 's/tool_groups:/tool_groups:\
- toolgroup_id: mcp::weather-data\
  provider_id: model-context-protocol\
  mcp_endpoint:\
    uri: http:\/\/weather-mongodb-mcp.admin-workshop.svc.cluster.local:8000\/mcp/' > /tmp/patched-config.yaml

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
echo "✅ LlamaStack restarted with Weather MCP!"
```

> 📝 **What just happened?** 
> - We exported the current config created by the operator
> - Added the Weather MCP (from the shared `admin-workshop` namespace) to the `tool_groups` section
> - Replaced the ConfigMap with the patched version
> - Restarted the pod to load the new config



---

## Step 2.6: Check What Tools Are Available

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

You should see about **5 tools** (all weather-related).

> 📝 **Note:** The HR tool is available but not connected to your AI yet. We'll add it in Part 3!

---

## Step 2.7: Run the Notebook (First Time)

A "notebook" is an interactive document where you can run code. Let's try it!

### Create a Workbench:

1. **Go to** your project in OpenShift AI Dashboard
2. **Click** on **"Workbenches"** tab
3. **Click** **"Create workbench"**
4. **Fill in the form:**

   | Field | What to Select/Enter |
   |-------|---------------------|
   | **Name** | `user-XX` (use your user number, e.g., `user-25`) |
   | **Image selection** | `Jupyter | Data Science | CPU | Python 3.12` |
   | **Version selection** | `2025.2` (or latest available) |
   | **Deployment size** | `Small` is fine |

   > 💡 **Tip:** You can leave the Description, Environment variables, Cluster storage, and Connections sections as default.

5. **Click** **"Create workbench"** button at the bottom
6. **Wait** for the status to show **"Running"** (1-2 minutes)
7. **Click** the **"Open"** link to launch JupyterLab

### Get the Workshop Notebook:

8. In JupyterLab, look at the top menu
9. **Click** **"Git"** → **"Clone a Repository"**
10. **Paste** this URL:
    ```
    https://github.com/gymnatics/llamastack-demo.git
    ```
11. **Click** **"Clone"**

12. **Switch to the workshop branch:**
    - In JupyterLab, open a **Terminal** (File → New → Terminal)
    - Run these commands:
      ```bash
      cd llamastack-demo
      git checkout workshop-branch
      ```
    - You should see: `Switched to branch 'workshop-branch'`

13. In the file browser on the left, **navigate to:**
    `llamastack-demo` → `notebooks` → `workshop_client_demo.ipynb`
14. **Double-click** to open it

### Run the Notebook:

15. **Find the cell** that says `PROJECT_NAME = "user-XX"`
16. **Change** `user-XX` to your actual user number (e.g., `user-25`)
17. **Click** the **"Run All"** button (▶▶) at the top, or go to **Run** → **Run All Cells**

**Look at the output!** You should see:
- 1 LLM model available
- About 5 MCP tools (Weather only)

> 🎯 **Key Learning:** Even though you can see BOTH Weather and HR MCP servers in the AI Asset Endpoints UI, the notebook only shows Weather tools. That's because **only Weather is configured in your LlamaStack's `tool_groups`**. The UI shows what's *available*, but the ConfigMap controls what's *connected*.

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
    uri: http://weather-mongodb-mcp.admin-workshop.svc.cluster.local:8000/mcp
- toolgroup_id: builtin::rag
  provider_id: rag-runtime
```

Notice: Only Weather MCP and builtin RAG are listed - no HR MCP yet!

---

## Step 3.2: Add HR MCP to the Configuration

Now let's add the HR MCP tool to the configuration using the same patching approach.

> 📝 **Note:** The HR MCP server is also shared and running in the `admin-workshop` namespace.

**Copy and paste these commands:**

```bash
# Step 1: Get the current config
oc get configmap llama-stack-config -n $NS -o jsonpath='{.data.run\.yaml}' > /tmp/current-config.yaml

# Step 2: Add HR MCP to the config (after Weather MCP)
cat /tmp/current-config.yaml | sed 's/- toolgroup_id: builtin::rag/- toolgroup_id: mcp::hr-tools\
  provider_id: model-context-protocol\
  mcp_endpoint:\
    uri: http:\/\/hr-mcp-server.admin-workshop.svc.cluster.local:8000\/mcp\
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

You should now see **about 10 tools**, including:
- Weather tools (from before)
- HR tools (NEW!) like `list_employees`, `get_vacation_balance`, etc.

---

## Step 3.5: Test the HR Tool in the Playground

Go back to the **Playground** in your browser and try these prompts:

> 💡 **Tip:** HR tools work well with direct requests. Here are recommended prompts:

**List employees (simple, always works):**
```
List all employees
```

**Get specific employee info:**
```
Get employee info for EMP001
```

**Check vacation balance:**
```
Get vacation balance for employee EMP001
```

**Find job openings:**
```
List all job openings
```

**Create a vacation request:**
```
Create a vacation request for employee EMP002 from 2026-02-10 to 2026-02-14
```

> 📝 **Employee IDs:** EMP001 = Alice Johnson, EMP002 = Bob Smith, EMP003 = Carol Williams

**Use BOTH tools together:**
```
List all weather stations and list all employees
```

```
Get weather statistics and list job openings
```

🎉 **Your AI is now using BOTH the weather AND HR tools!**

> ⚠️ **Troubleshooting:** If a complex query fails, try breaking it into simpler requests. For example, instead of "What's the weather in Tokyo and how many vacation days does Alice have?", try asking each question separately.




---

## Step 3.6: What You Just Learned

| Before (Part 2) | After (Part 3) |
|-----------------|----------------|
| 1 tool group (Weather) | 2 tool groups (Weather + HR) |
| ~5 tools | ~10 tools |
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
- MCP Tools: ~5 (Weather only)

**Part 5 (second run):**
- MCP Tools: ~10 (Weather + HR)

🎯 **The notebook code didn't change at all!** The same code automatically discovered the new HR tools because you updated the LlamaStack configuration.

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
✅ Connected shared MCP tools (Weather, HR) to your AI  
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

## Shared MCP Server URLs

These MCP servers are shared and running in the `admin-workshop` namespace:

| Tool | URL |
|------|-----|
| Weather | `http://weather-mongodb-mcp.admin-workshop.svc.cluster.local:8000/mcp` |
| HR | `http://hr-mcp-server.admin-workshop.svc.cluster.local:8000/mcp` |

---

**Thank you for attending! 🙏**

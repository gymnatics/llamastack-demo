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

✅ **Success!** You should now see your project `user-XX` in the list.

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

✅ **Success!** You should see `gpu-profile` in the hardware profiles list.

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
   | **Name** | `llama-3.2-3b-instruct` |
   | **URI** | (copy the text below exactly) |

   ```
   oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct
   ```

   > 💡 **Tip:** Triple-click the URI above to select it all, then copy and paste.

7. **Click** the **"Create"** button

✅ **Success!** You should see `llama-3.2-3b-instruct` in your connections list.

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
   | **Model connection** | Select `llama-3.2-3b-instruct` |

5. **Scroll down** to find **"Model server configuration"**
   - Set **Replicas** to `1`
   - ✅ Check the box **"Make deployed models available as AI assets"**

6. **Click** the **"Deploy"** button

---

## Step 1.6: Wait for Your Model to Start

The model needs a few minutes to download and start up.

1. You'll see your model in the list with a status indicator
2. **Wait** for the status to change:
   - 🟡 **Pending** → Model is being prepared
   - 🔵 **Progressing** → Model is downloading/starting
   - 🟢 **Running** → Model is ready! ✅

> ⏱️ **This takes about 3-5 minutes.** Feel free to stretch or grab water!

### How to Check if It's Ready (Optional)

Open your terminal and run:

```bash
oc get pods -n user-XX | grep llama
```

> ⚠️ **Remember:** Replace `user-XX` with your actual user number!

When it's ready, you'll see:
```
llama-32-3b-instruct-predictor-xxxxx   1/1   Running   0   2m
```

The `1/1` and `Running` mean it's working!

✅ **Success!** Your AI model is now running!

---

# Part 2: Add AI Tools & Test the Playground (30 min)

Now we'll add "tools" that give your AI special abilities, like checking the weather!

## Step 2.1: Open Your Terminal

We need to run some commands. Open your terminal (see "Opening Your Terminal" above if you need help).

---

## Step 2.2: Set Up Your Workspace

First, let's set a shortcut so you don't have to type your project name every time.

**Copy and paste this command** (replace XX with your number):

```bash
export NS=user-XX
```

For example, if you're user 5:
```bash
export NS=user-05
```

Press `Enter`. You won't see any output - that's normal!

---

## Step 2.3: Download the Workshop Files

Now let's download the files we need.

**Copy and paste these commands one at a time:**

```bash
git clone https://github.com/<org>/llamastack-demo.git
```

Press `Enter` and wait for it to finish.

```bash
cd llamastack-demo
```

Press `Enter`.

```bash
git checkout workshop-branch
```

Press `Enter`.

✅ **Success!** You now have all the workshop files.

---

## Step 2.4: Deploy the Weather Tool

Let's give your AI the ability to check the weather!

**Copy and paste this command:**

```bash
oc apply -f manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml -n $NS
```

Press `Enter`. You'll see several lines saying things were "created".

---

## Step 2.5: Deploy the HR Tool

Let's also deploy an HR (Human Resources) tool. We'll use it later!

**Copy and paste this command:**

```bash
oc apply -f manifests/workshop/deploy-hr-mcp-simple.yaml -n $NS
```

Press `Enter`.

---

## Step 2.6: Wait for the Tools to Start

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

## Step 2.7: Register the Tools in OpenShift

Now we need to tell OpenShift about these tools.

1. **Go back to your browser** (OpenShift AI Dashboard)
2. Make sure you're in your project (`user-XX`)
3. **Click** on **"AI Asset Endpoints"** in the left menu or project tabs

### Register the Weather Tool:

4. **Click** **"Add endpoint"**
5. **Select** **"MCP Server"**
6. **Fill in:**

   | Field | What to Enter |
   |-------|---------------|
   | **Name** | `weather-mcp` |
   | **URL** | `http://weather-mongodb-mcp:8000/mcp` |

7. **Click** **"Add"** or **"Create"**

### Register the HR Tool:

8. **Click** **"Add endpoint"** again
9. **Select** **"MCP Server"**
10. **Fill in:**

    | Field | What to Enter |
    |-------|---------------|
    | **Name** | `hr-mcp` |
    | **URL** | `http://hr-mcp-server:8000/mcp` |

11. **Click** **"Add"** or **"Create"**

✅ **Success!** Both tools are registered.

---

## Step 2.8: Enable the AI Playground

The "Playground" is a chat interface where you can talk to your AI.

1. Stay on the **"AI Asset Endpoints"** page
2. **Find** your model `llama-32-3b-instruct` in the list
3. **Click** the **"Add to Playground"** button next to it
4. **Wait** about 2 minutes for the Playground to be created

> 💡 You might see a loading indicator. Just wait for it to finish.

---

## Step 2.9: Test Your AI in the Playground!

Let's chat with your AI!

1. **Click** on **"GenAI Studio"** in the left menu
2. **Click** on **"Playground"**
3. You should see a chat interface
4. **Select your model** from the dropdown (if not already selected)

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

### Run the Notebook:

14. **Find the cell** that says `PROJECT_NAME = "user-XX"`
15. **Change** `user-XX` to your actual user number (e.g., `user-05`)
16. **Click** the **"Run All"** button (▶▶) at the top, or go to **Run** → **Run All Cells**

**Look at the output!** You should see:
- 1 LLM model available
- About 3 MCP tools (Weather only)

✅ **Success!** You've completed Part 2!

---

# Part 3: Add More Tools to Your AI (30 min)

Now let's add the HR tool to your AI. This shows how easy it is to expand your AI's capabilities!

## Step 3.1: See the Current Configuration

Let's look at what tools your AI is currently configured to use.

**In your terminal, run:**

```bash
oc get configmap llama-stack-config -n $NS -o yaml | grep -A15 "tool_groups:"
```

You'll see something like:
```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  ...
```

Notice: Only the weather tool is listed!

---

## Step 3.2: Update the Configuration

Now let's add the HR tool to the configuration.

**Copy and paste this command:**

```bash
oc apply -f manifests/workshop/llama-stack-config-workshop-phase2.yaml -n $NS
```

You should see:
```
configmap/llama-stack-config configured
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
oc wait --for=condition=available deployment/lsd-genai-playground -n $NS --timeout=120s
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

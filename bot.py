import discord
from discord.ext import commands, tasks
from discord.ext.commands import AutoShardedBot
import itertools
import json
import config as config
import asyncio
import os
import logging
from datetime import datetime
from typing import List, Optional, Dict

# ====== Setup Logging ======
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[
        logging.FileHandler('discord_bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('DiscordBot')

# ====== Setup Intents ======
intents = discord.Intents.default()
intents.message_content = True
intents.members = True
intents.guilds = True

# ====== Create AutoShardedBot ======
class CustomBot(AutoShardedBot):
    def __init__(self):
        super().__init__(
            command_prefix=self.get_prefix,
            intents=intents,
            case_insensitive=True,
            help_command=commands.DefaultHelpCommand(),
            allowed_mentions=discord.AllowedMentions(
                everyone=False,
                roles=False,
                replied_user=False
            ),
            strip_after_prefix=True
        )
        self.activity_cycle = itertools.cycle([
            discord.Activity(type=discord.ActivityType.watching, name="n!help | n!invite"),
            discord.Activity(type=discord.ActivityType.playing, name="Developed by ArkDevLabs"),
            discord.Activity(type=discord.ActivityType.playing, name="Join our support server!"),
            discord.Activity(type=discord.ActivityType.playing, name="Use n!stats to see my stats")
        ])
        self.commands_synced = False
        self.start_time = datetime.utcnow()
        self.extensions_loaded: Dict[str, bool] = {}

    async def get_prefix(self, message):
        default_prefixes = "n!"
        return commands.when_mentioned_or(*default_prefixes)(self, message)

bot = CustomBot()

# ====== Activity Cycling with Enhanced Error Handling ======
@tasks.loop(minutes=15)
async def rotate_activity():
    """Rotates bot activity/status with error recovery"""
    try:
        activity = next(bot.activity_cycle)
        await bot.change_presence(
            activity=activity,
            status=discord.Status.dnd
        )
        logger.info(f"Activity changed: {activity.name}")
    except discord.HTTPException as e:
        if e.status == 429:
            wait_time = getattr(e, 'retry_after', 60)
            logger.warning(f"Rate limited. Waiting {wait_time:.1f}s before retry")
            await asyncio.sleep(wait_time)
        else:
            logger.error(f"HTTPException during activity change: {e}")
    except Exception as e:
        logger.error(f"Failed to change activity: {e}", exc_info=True)

@rotate_activity.before_loop
async def before_activity_rotation():
    """Wait for bot to be ready before starting activity rotation"""
    await bot.wait_until_ready()
    logger.info("Activity rotation task started")

# ====== Extension Loading System ======
async def load_extensions():
    """Load all extensions from the cogs directory"""
    cogs_dir = "./cogs"
    success_count = 0
    fail_count = 0
    
    if not os.path.exists(cogs_dir):
        logger.warning(f"Cogs directory '{cogs_dir}' not found. Creating it...")
        os.makedirs(cogs_dir)
        return
    
    for filename in sorted(os.listdir(cogs_dir)):
        if filename.endswith(".py") and not filename.startswith("_"):
            extension = f"cogs.{filename[:-3]}"
            try:
                await bot.load_extension(extension)
                bot.extensions_loaded[extension] = True
                success_count += 1
                logger.info(f"✓ Loaded: {extension}")
            except Exception as e:
                bot.extensions_loaded[extension] = False
                fail_count += 1
                logger.error(f"✗ Failed to load {extension}: {e}")
    
    logger.info(f"Extension loading complete: {success_count} succeeded, {fail_count} failed")

# ====== Command Tree Synchronization ======
async def synchronize_commands():
    if bot.commands_synced:
        logger.info("Commands already synced this session")
        return
    
    max_retries = 3
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            synced_commands = await bot.tree.sync()
            bot.commands_synced = True
            logger.info(f"Synced {len(synced_commands)} application commands")
            return
        except discord.HTTPException as e:
            if e.status == 429:
                wait_time = getattr(e, 'retry_after', 30)
                logger.warning(f"Rate limited during sync. Retry {retry_count + 1}/{max_retries} in {wait_time:.1f}s")
                await asyncio.sleep(wait_time)
                retry_count += 1
            else:
                logger.error(f"HTTP error during command sync: {e}")
                break
        except Exception as e:
            logger.error(f"Unexpected sync error: {e}", exc_info=True)
            break
    
    if retry_count >= max_retries:
        logger.error("Failed to sync commands after maximum retries")

# ====== Setup Hook ======
async def on_setup():
    logger.info("Running setup hook...")
    
    await load_extensions()
    
    # Start background tasks
    if not rotate_activity.is_running():
        rotate_activity.start()
    
    # Sync commands if configured
    if hasattr(config, 'AUTO_SYNC') and config.AUTO_SYNC:
        await synchronize_commands()
    
    logger.info("Setup hook completed")

bot.setup_hook = on_setup

# ====== Event Handlers ======
@bot.event
async def on_ready():
    logger.info("=" * 50)
    logger.info(f"Bot User: {bot.user}")
    logger.info(f"Bot ID: {bot.user.id}")
    logger.info(f"Discord.py Version: {discord.__version__}")
    logger.info(f"Total Guilds: {len(bot.guilds)}")
    logger.info(f"Total Users: {len(bot.users)}")
    logger.info(f"Shard Count: {bot.shard_count}")
    logger.info(f"Latency: {round(bot.latency * 1000)}ms")
    logger.info("=" * 50)

    if bot.user:
        perms = discord.Permissions(administrator=True)
        invite = discord.utils.oauth_url(bot.user.id, permissions=perms)
        logger.info(f"Invite Link: {invite}")

@bot.event
async def on_shard_ready(shard_id: int):
    """Called when a specific shard becomes ready"""
    logger.info(f"Shard {shard_id} is ready")

@bot.event
async def on_shard_resumed(shard_id: int):
    """Called when a shard resumes connection"""
    logger.info(f"Shard {shard_id} resumed connection")

@bot.event
async def on_guild_join(guild: discord.Guild):
    """Called when bot joins a new guild"""
    logger.info(f"Joined new guild: {guild.name} (ID: {guild.id}) - Members: {guild.member_count}")

@bot.event
async def on_guild_remove(guild: discord.Guild):
    """Called when bot is removed from a guild"""
    logger.warning(f"Removed from guild: {guild.name} (ID: {guild.id})")


async def start_bot():
    """Initialize and start the bot"""
    async with bot:
        try:
            logger.info("Starting bot...")
            await bot.start(config.TOKEN)
        except KeyboardInterrupt:
            logger.info("Keyboard interrupt received")
        except discord.LoginFailure:
            logger.critical("Invalid token! Please check your config.py")
        except discord.PrivilegedIntentsRequired:
            logger.critical("Missing privileged intents. Enable them in Discord Developer Portal")
        except Exception as e:
            logger.critical(f"Fatal startup error: {e}", exc_info=True)
        finally:
            if not bot.is_closed():
                logger.info("Closing bot connection...")
                await bot.close()
            logger.info("Bot shutdown complete")

if __name__ == "__main__":
    try:
        asyncio.run(start_bot())
    except KeyboardInterrupt:
        logger.info("Process interrupted by user")
    except Exception as e:
        logger.critical(f"Critical error in main process: {e}", exc_info=True)

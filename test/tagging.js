const Tags = artifacts.require("Tags");
const Provider = artifacts.require("Provider");

const truffleAssert = require("truffle-assertions");

contract("Tags", (accounts) => {
  let provider_1, provider_2, user_1, user_2, owner;
  [owner, provider_1, provider_2, user_1, user_2] = accounts;

  beforeEach("setup providers", async () => {
    const providerInstances = await Provider.deployed();
    await providerInstances.registerProvider(provider_1, {from: owner});
    await providerInstances.registerProvider(provider_2, {from: owner});
  });

  it("should mint the correct amount on deployment", async () => {
    const tagsInstance = await Tags.deployed();
    let balance = await tagsInstance.balanceOf(tagsInstance.address);
    assert.equal(balance.toNumber(), 1000);
  });

  it("shouldn't be able to create a tag if not provider", async () => {
    const tagsInstance = await Tags.deployed();
    let fn = tagsInstance.createTag({ from: owner });
    await truffleAssert.reverts(fn, "");
  });

  it("should be able to create a tag if provider", async () => {
    const tagsInstance = await Tags.deployed();
    let createTagTx = await tagsInstance.createTag({ from: provider_1 });
    assert.strictEqual(createTagTx.receipt.logs.length, 1);
    assert.strictEqual(createTagTx.logs.length, 1);
    const log = createTagTx.logs[0];
    assert.strictEqual(log.event, "TagIdGeneratedEvent");
    assert.strictEqual(log.args.creator, provider_1);
    assert.ok(log.args.tagId);
    let tag = await tagsInstance.tags(log.args.tagId);
    assert.strictEqual(tag.balance.toNumber(), 50);
    assert.strictEqual(tag.provider, provider_1);    
  });


  it("should be able to feed a tag when at maximum", async () => {
    const tagsInstance = await Tags.deployed();
    let createTagTx = await tagsInstance.createTag({ from: provider_1 });
    const log = createTagTx.logs[0];
    let fn = tagsInstance.feedTag(log.args.tagId);
    await truffleAssert.reverts(fn, "Tag is at maximum");
  });

  it("the provider should be the only able to remove the tag", async () => {
    const tagsInstance = await Tags.deployed();
    let createTagTx = await tagsInstance.createTag({ from: provider_1 });
    const log = createTagTx.logs[0];
    let fn = tagsInstance.clearTag(log.args.tagId, {from: provider_2});
    await truffleAssert.reverts(fn, "");
    let clearTagTx = await tagsInstance.clearTag(log.args.tagId, {from: provider_1});
    const clearLog = clearTagTx.logs[0];
    assert.strictEqual(clearLog.event, "TagIdRemovedEvent");
    assert.strictEqual(clearLog.args.tagId, log.args.tagId);
  });

  it("the user should be able to create a claim for a tag", async () => {
    const tagsInstance = await Tags.deployed();
    let createTagTx = await tagsInstance.createTag({ from: provider_1 });
    const log = createTagTx.logs[0];
    let tagId = log.args.tagId;
    let createClaimTx = await tagsInstance.createClaimForTag(tagId);
    const logClaim = createClaimTx.logs[0];
    assert.strictEqual(logClaim.event, "ClaimGeneratedEvent");
  });
});

package cn.byb.appdemo;

import cn.byb.appdemo.client.DemoDO;
import cn.tongdun.config.annotation.ConfigurationChangeListener;
import cn.tongdun.config.annotation.FieldInfo;
import cn.tongdun.config.annotation.ShutterProperties;
import cn.tongdun.config.client.ConfigClient;
import cn.tongdun.config.client.constants.ConfigType;
import cn.tongdun.config.client.model.ConfigMetadata;
import cn.tongdun.config.client.observer.ConfigChangeListener;
import cn.tongdun.config.file.utils.PropertiesUtils;
import cn.tongdun.config.spring.ConfigRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.support.ApplicationObjectSupport;
import org.springframework.stereotype.Component;

import javax.annotation.PostConstruct;
import java.util.Properties;

/**
 * Created by byb on 24/5/6.
 */
@ShutterProperties(location = "appdemo.properties", application = "appdemo", cluster = "DEFAULT", prefix = "shutter",
    changeConfig = true)
@Component
public class ShutterDemo extends ApplicationObjectSupport implements ConfigChangeListener {

    @Autowired
    private ConfigRepository repository;

    @Autowired
    private Properties f25017f9d0944b3ca38ed86e923cb638;

    @Value("${zookeeper.hostList}")
    private String zkmain;

    @Value("${configcenter.endpoint}")
    private String endpoint;

    //shutter会最后覆盖properties中的配置
    @Value("${test}")
    private String value;

    //以下2配置可在shutter-dev页面中找到
    private String testValue;

    @FieldInfo(value = "a")
    private String a;

    public String getZkmain() {
        return zkmain;
    }

    public void setZkmain(String zkmain) {
        this.zkmain = zkmain;
    }

    public String getEndpoint() {
        return endpoint;
    }

    public String getEnv() {
        String env = System.getenv("ENV");
        if (env == null) {
            env = getApplicationContext().getEnvironment().getProperty("shutter.environment");
        }
        return env;
    }

    @PostConstruct
    public void init() throws Exception {
        // 需要查看内容，可以使用这个方式down出来
        System.out.println(PropertiesUtils.store(f25017f9d0944b3ca38ed86e923cb638));
        System.out.println(">> ENV properties:" + getEnv());
        System.out.printf(">> shutter properties injected: %s\n", getZkmain());
        System.out.printf(">> shutter properties injected with @Value annotation: %s\n", getEndpoint());
        DemoDO demoDO = new DemoDO();
        demoDO.setAge(1);
        demoDO.setName(String.valueOf(System.currentTimeMillis()));
        System.out.println(">> ShutterDemo started without failure");

        System.out.println(">> Runtime: APP:" + repository.getApplication());
        System.out.println(">> Runtime: CLUSTER:" + repository.getCluster());
        System.out.println(">> Runtime: ENV:" + repository.getEnvironment());

    }

    // 以下是监听的demo
    @ConfigurationChangeListener(application = "appdemo",cluster = "DEFAULT",location = "appdemo.properties",type = ConfigType.FILE)
    @Override
    public void onChange(ConfigMetadata metadata) throws Exception {
        if (repository.isDisabled()) {
            return;
        }
        System.out.println(">> Runtime: shutter.testValue:" + getTestValue());
        System.out.println(">> Runtime: test:" + value);
        System.out.println(">> Runtime: a:" + getA());
        ConfigClient client = repository.getClient();
        // 在关闭应用时，会强制中断监听，产生CANCELLED异常是正常的情况
        String file = client.getConfig(metadata, this);
        // properties解析
        // Properties properties = new Properties();
        // properties.load(new StringReader(file));

        // yaml解析
        // Yaml yaml = new Yaml();
        // yaml.loadAs(file, Class.class);

        // 下面是封装过的方便解析。
        // client.file()
        // client.item()
    }

    public String getTestValue() {
        return testValue;
    }

    public void setTestValue(String testValue) {
        this.testValue = testValue;
    }

    public String getA() {
        return a;
    }

    public void setA(String a) {
        this.a = a;
    }
}
